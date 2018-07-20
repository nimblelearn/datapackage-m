/*
MIT License

Copyright (c) 2018 Nimble Learn Ltd (http://www.nimblelearn.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

// Returns a Tabular Data Resource as a table
let
    DataPackage.Table = (
        dataPackageIdentifier as text,              // A valid Data Package Identifier
        optional dataResourceIndex as number,       // A valid Data Resource index
        optional dataResourceName as text,          // A valid Data Resource name
        optional ignoreTableSchemaTypes as logical  // Controls whether the Table Schema is applied to the data
    ) as table =>
    let       
        // Set up local references for shared functions
        DataPackage.Helper = DataPackageHelper,
        DataPackage.Package = DataPackage.Helper("DataPackage.Package"),
        DataPackage.Resource = DataPackage.Helper("DataPackage.Resource"),
        DataPackage.ConvertFieldType = DataPackage.Helper("DataPackage.ConvertFieldType"),
        DataPackage.ConvertFieldValue = DataPackage.Helper("DataPackage.ConvertFieldValue"),
        
        // Ensure ignoreTableSchemaTypes has a true/false value
        ignoreTableSchemaTypes = if ignoreTableSchemaTypes = null then
                                false
                            else
                                ignoreTableSchemaTypes,               
        
        // Deserialise the Data Package metadata
        DataPackage = DataPackage.Package(dataPackageIdentifier),                
        
        // Assign the list of resources to a variable
        DataResources = DataPackage[resources],
        
        // Load the selected data resource
        DataResource = if dataResourceName <> null then
                           // Get the resource by name
                           List.Select(DataResources, each _[name] = dataResourceName){0}
                       else 
                           //Get the resource by index
                           DataResources{dataResourceIndex},
        UntypedData = DataPackage.Resource(DataResource),
        
        // Get the schema metadata 
        Schema = DataResource[__resolvedschema],
        FieldCount = List.Count(Schema[fields]),
        FieldNames = List.Transform(Schema[fields], each [name]), 
        FieldTypes = List.Transform(Schema[fields], each [type]),
    
        // Apply the DataPackage.ConvertFieldType function
        MFieldTypes = List.Transform(FieldTypes, each DataPackage.ConvertFieldType(_)),
        
        // Create a list combining the field names mapped to M data types
        FieldNamesAndTypes = List.Zip({FieldNames, FieldTypes, MFieldTypes}),
    
        // Iterate over the list of field type mappings and generate a text list of type transformations
        TypeTransformationsAsListOfText = List.Transform(
                                              FieldNamesAndTypes,
                                              each "{""" & _{0} & """, type " & _{2} & "}"
                                          ),
        // Iterate over the list of field type mappings and generate a text list of value transformations
        ValueTransformationsAsListOfText = List.Transform(
                                               FieldNamesAndTypes,
                                               each "{""" & _{0} & """, each DataPackage.ConvertFieldValue(""" & _{1} & """, _)}"
                                           ),    
        
        // Prepare the list of text for conversion into a list of lists
        TypeTransformationsAsText = "{" & Text.Combine(TypeTransformationsAsListOfText, ", ") & "}",
        ValueTransformationAsText = "{" & Text.Combine(ValueTransformationsAsListOfText, ", ") & "}",
     
        // Evaluate the generated expression to create the list of lists to be used for column type transformations
        TypeTransformations = Expression.Evaluate(TypeTransformationsAsText),
    
        // Apply the value transformations    
        ValueTransformations = Expression.Evaluate(ValueTransformationAsText, [DataPackage.ConvertFieldValue = DataPackage.ConvertFieldValue]),
    
        // Create a list mapping the header column names (old) with the ones from the schema fields (new)
        OldAndNewColumnNames = List.Zip({Table.ColumnNames(UntypedData), FieldNames}),
    
        // Iterate over the list of lists and generate a text list of old and new column names
        OldAndNewColumnNamesAsListOfText = List.Transform(
                                               OldAndNewColumnNames,
                                               each "{""" & _{0} & """, """ & _{1} & """}"
                                           ),
    
        // Prepare the list of text for conversion into a list of lists
        RenamedColumnsListAsText  = "{" & Text.Combine(OldAndNewColumnNamesAsListOfText, ", ") & "}",
        
        // Evaluate the generated expression to create the list of lists to be used for renaming the columns
        RenamedColumns = Expression.Evaluate(RenamedColumnsListAsText),    
     
        // Apply the column names taken from the schema
        UntypedDataWithRenamedColumns = Table.RenameColumns(UntypedData, RenamedColumns),
    
        // Make the field values M data type compatible
        ConformedData = Table.TransformColumns(UntypedDataWithRenamedColumns, ValueTransformations),
    
        // Apply the M data types to the columns
        ConformedAndTypedData = Table.TransformColumnTypes(ConformedData, TypeTransformations),
    
        // If both the provided resource index and resource name were not provided then we list all the resources, 
        // otherwise we return the corresponding resource data as a table.
        DataTable = if dataResourceName <> null or dataResourceIndex <> null then                  
                          // Determine whether to apply the JSON Table Schema to the data
                          if ignoreTableSchemaTypes = false then
                              ConformedAndTypedData
                          else
                              UntypedDataWithRenamedColumns  
                      else 
                        Record.ToTable(try error "A valid Data Resource name or index was not provided.")      
    in
        DataTable,

    // Add documentation
    DataPackage.TableWithDocumentation = type function (
                                   dataPackageIdentifier as (
                                       type text meta [
                                           Documentation.FieldCaption = "Data Package Identifier",
                                           Documentation.FieldDescription = "A valid Data Package Identifier",
                                           Documentation.SampleValues = {"https://datahub.io/core/gdp/datapackage.json"}
                                       ]
                                   ),
                                   optional dataResourceIndex as (
                                       type number meta [
                                           Documentation.FieldCaption = "Data Resource Index",
                                           Documentation.FieldDescription = "A valid Data Resource index",
                                           Documentation.SampleValues = {0}
                                       ]
                                   ),
                                   optional dataResourceName as (
                                       type text meta [
                                           Documentation.FieldCaption = "Data Resource Name",
                                           Documentation.FieldDescription = "A valid Data Resource name",
                                           Documentation.SampleValues = {"gdp"}
                                       ]
                                   ),
                                   optional ignoreTableSchemaTypes as (
                                       type logical meta [
                                           Documentation.FieldCaption = "Ignore Table Schema Types",
                                           Documentation.FieldDescription = "Controls whether the Table Schema is applied to the data",
                                           Documentation.SampleValues = {false}
                                       ]
                                   )
                               ) as table meta [
                                   Documentation.Name = "DataPackage.Table",
                                   Documentation.LongDescription = "Returns a Tabular Data Resource as a <code>table</code>.
                                                                   <br><br>Example:
                                                                   <br>
                                                                   <br>
                                                                   <code>let
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;// Setup the shared function reference
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;DataPackage.Table = DataPackageTable,
                                                                   <br>
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;// Invoke the function
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;Source = DataPackage.Table(""https://datahub.io/core/gdp/datapackage.json"", null, ""gdp"")
                                                                   <br>in
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;Source</code>
                                                                   <br>
                                                                   <br>
                                                                   More documentation available at: https://github.com/nimblelearn/datapackage-m",                                   
                                   Documentation.Examples = null
                               ]
in
    Value.ReplaceType(DataPackage.Table, DataPackage.TableWithDocumentation)