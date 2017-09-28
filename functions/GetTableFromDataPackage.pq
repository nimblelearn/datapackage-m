/*
MIT License

Copyright (c) 2017 Nimble Learn Ltd (http://www.nimblelearn.com)

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

//Transform a Data Package resource (specified by name or index) into a table and use the JSON Table Schema to apply the correct data types. If a resource name or index is not provided, return a table that lists all of the Data Package's resources.
(
  Path as text, 
  optional ResourceIndex as number,       //A resource will always have an index
  optional ResourceName as text,          //A resource may have a name
  optional IgnoreSchemaTypes as logical   //For scenarios when applying the field types from the schema causes load issues
) as table =>
let       
    //Ensure IgnoreSchemaTypes has a true/false value
    IgnoreSchemaTypes = if IgnoreSchemaTypes = null then
                            false
                          else
                            IgnoreSchemaTypes,

    //The data package spec states that the descriptor file MUST be named datapackage.json
    descriptor = "datapackage.json",
    
    //Determine if the Data Package is local or remote
    DataPackageLocationType = if Text.Contains(BasePath, "http") then
                                   "remote"
                                 else
                                   "local",

    //Add a trailing slash to the base path if it doesn't already exist
    BasePath = Text.Replace(
                  if Text.Contains(Path, "http") then 
                    (if Text.End(Path, 1) <> "/" and Text.Contains(Path, "datapackage.json") = false then Path & "/" else Path)
                  else 
                    (if Text.End(Path, 1) <> "\" and Text.Contains(Path, "datapackage.json") = false then Path & "\" else Path),
                  "datapackage.json", 
                  ""
                ),
    
    //Build the fully qualified path of the datapackage.json descriptor file
    DescriptorPath = BasePath & descriptor,
    
    //Deserialise the Data Package metatdata
    DataPackage = if DataPackageLocationType = "remote" then
                     Json.Document(Web.Contents(DescriptorPath))
                   else                      
                     Json.Document(File.Contents(DescriptorPath)),                
    
    //Convert the list of resource records into a table and then expand the record columns
    AllResourcesAsList = DataPackage[resources],
    AllResourcesAsTable = Table.FromList(AllResourcesAsList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    AllResources = Table.ExpandRecordColumn(AllResourcesAsTable, "Column1", {"name", "path", "schema"}, {"name", "path", "schema"}),
    AllResourcesWithAddedIndex = Table.AddIndexColumn(AllResources, "index", 0, 1),
    AllResourcesWithAddedData = Table.AddColumn(AllResourcesWithAddedIndex, "data", each if Text.Contains(_[path], ".csv") then
                                                                                                   GetTableFromDataPackage(Path, _[index], null, IgnoreSchemaTypes)
                                                                                                 else 
                                                                                                   null),
    AllResourcesWithAddedDataBuffered = Table.Buffer(AllResourcesWithAddedData),
    
    //Select the required resource based on name or index
    SelectedResource = Table.SelectRows(AllResourcesWithAddedIndex, each (([name] = ResourceName and ResourceIndex = null) or ([index] = ResourceIndex and ResourceName = null))),
    SelectedResourcePath = SelectedResource[path]{0},
    
    //Build the fully qualified resource path. If the resource path is not a fully qualified URL then it's treated as a relative path.
    ResourcePath = if Text.Contains(SelectedResourcePath, "http") then 
                      SelectedResourcePath
                    else 
                      BasePath & Text.From(SelectedResourcePath),
    
    //Extract the schema metadata
    AllFieldsAsList = Table.ExpandRecordColumn(SelectedResource, "schema", {"fields"}, {"fields"}),
    ExpandedFields = Table.ExpandListColumn(AllFieldsAsList, "fields"),
    ExpandedFieldRows = Table.ExpandRecordColumn(ExpandedFields, "fields", {"name", "type"}, {"field_name", "field_type"}),
    
    FieldCount = List.Count(ExpandedFieldRows[field_name]),
    FieldNames = ExpandedFieldRows[field_name], 
    FieldTypes = ExpandedFieldRows[field_type],
    
    //Map the JSON Table Schema field types to M data types
    MFieldTypes = List.Transform(FieldTypes, each MapDataPackageFieldType(_)),
    
    //Create a list combining the field names mapped to M data types
    FieldNamesAndTypes = List.Zip({FieldNames, FieldTypes, MFieldTypes}),

    //Loop through the list of field type mappings and generate a text list of type transformations
    TypeTransformationsAsListOfText = List.Generate(
                                            ()=>[ListItems = FieldNamesAndTypes, ItemIndex = 0],
                                            each [ItemIndex] < FieldCount,
                                            each [ListItems=[ListItems], ItemIndex = [ItemIndex] + 1],
                                            each "{""" & [ListItems]{[ItemIndex]}{0} & """, type " & [ListItems]{[ItemIndex]}{2} & "}"
                                          ),
    //Loop through the list of field type mappings and generate a text list of value transformations
    ValueTransformationsAsListOfText = List.Generate(
                                            ()=>[ListItems = FieldNamesAndTypes, ItemIndex = 0],
                                            each [ItemIndex] < FieldCount,
                                            each [ListItems=[ListItems], ItemIndex = [ItemIndex] + 1],
                                            each "{""" & [ListItems]{[ItemIndex]}{0} & """, each TransformDataPackageFieldValue(""" & [ListItems]{[ItemIndex]}{1} & """, _)}"
                                          ),    
    
    //Prepare the the list of text for conversion into a list of lists
    TypeTransformationsAsText = "{" & Text.Combine(TypeTransformationsAsListOfText, ", ") & "}",
    ValueTransformationAsText = "{" & Text.Combine(ValueTransformationsAsListOfText, ", ") & "}",
 
    //Evaluate the generated expression to create the list of lists to be used for column type transformations
    TypeTransformations = Expression.Evaluate(TypeTransformationsAsText),

    //Explicitly exposed the TransformDataPackageFieldValue function to the Expression.Evaluate context
    ValueTransformations = Expression.Evaluate(ValueTransformationAsText, [TransformDataPackageFieldValue=TransformDataPackageFieldValue]),
    
    //Load the resource
    UntypedResourceData = if Text.Contains(SelectedResourcePath, "http") = true or (DataPackageLocationType = "remote" and Text.Contains(SelectedResourcePath, "http") = false) then
                              //This is a fully qualified URL or a fully qualified URL was derived from the base path and relative path
                              Csv.Document(Web.Contents(ResourcePath),[Delimiter=",", Columns=FieldCount, Encoding=65001])
                            else
                              //This is a local resource
                              Csv.Document(File.Contents(ResourcePath),[Delimiter=",", Columns=FieldCount, Encoding=65001]),

    //Promote the first row to the header
    UntypedResourceDataWithPromotedHeader = Table.PromoteHeaders(UntypedResourceData),  

    //Create a list mapping the header column names (old) with the ones from the schema fields (new)
    OldAndNewColumnNames = List.Zip({Table.ColumnNames(UntypedResourceDataWithPromotedHeader), FieldNames}),

    //Loop through the list of lists and generate a text list of old and new column namnes
    OldAndNewColumnNamesAsListOfText = List.Generate(
                                                 ()=>[ListItems = OldAndNewColumnNames, ItemIndex = 0],
                                                 each [ItemIndex] < FieldCount,
                                                 each [ListItems=[ListItems], ItemIndex = [ItemIndex] + 1],
                                                 each "{""" & [ListItems]{[ItemIndex]}{0} & """, """ & [ListItems]{[ItemIndex]}{1} & """}"
                                               ),

    //Prepare the the list of text for conversion into a list of lists
    RenamedColumnsListAsText  = "{" & Text.Combine(OldAndNewColumnNamesAsListOfText, ", ") & "}",
    
    //Evaluate the generated expression to create the list of lists to be used for renaming the columns
    RenamedColumns = Expression.Evaluate(RenamedColumnsListAsText),    
 
    //Apply the column names taken from the schema
    UntypedResourceDataWithRenamedColumns = Table.RenameColumns(UntypedResourceDataWithPromotedHeader, RenamedColumns),

    //Make the field values M data type compatible
    ConformedResourceData = Table.TransformColumns(UntypedResourceDataWithRenamedColumns, ValueTransformations),

    //Apply the M data types to the columns
    TypedResourceData = Table.TransformColumnTypes(ConformedResourceData, TypeTransformations),

    OutputTable = if ResourceName = null and ResourceIndex = null then
                     AllResourcesWithAddedDataBuffered
                   else 
                     //Determine whether to apply the JSON Table Schema or return all columns as text
                     if IgnoreSchemaTypes = false then
                       TypedResourceData
                     else
                       UntypedResourceDataWithRenamedColumns                       
in
    OutputTable