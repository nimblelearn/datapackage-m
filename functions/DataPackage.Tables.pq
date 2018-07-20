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

// Returns a table listing the Data Resources contained within a Data Package
let
    DataPackage.Tables = (
        dataPackageIdentifier as text,              // This can be a remote or local Data Package identifier
        optional ignoreTableSchemaTypes as logical  // Ignore the Table Schema due to there being unhandled field values, types, and/or formatting
    ) as table =>
    let       
        // Set up local references for shared functions
        DataPackage.Table = DataPackageTable,
        DataPackage.Helper = DataPackageHelper,
        DataPackage.Package = DataPackage.Helper("DataPackage.Package"),
        DataPackage.Resource = DataPackage.Helper("DataPackage.Resource"),
        
        // Ensure ignoreTableSchemaTypes has a true/false value
        ignoreTableSchemaTypes = if ignoreTableSchemaTypes = null then
                                false
                            else
                                ignoreTableSchemaTypes,               
        
        // Deserialise the Data Package metadata
        DataPackage = DataPackage.Package(dataPackageIdentifier),                
        
        // Convert the list of resource records into a table and then expand the record columns
        DataResources = DataPackage[resources],
        DataResourcesAsTable = Table.FromList(
                                   DataResources, 
                                   Splitter.SplitByNothing(), 
                                   {"ResourceProperties"}, 
                                   null, 
                                   ExtraValues.Error
                               ),
        ExpandedDataResourcesAsTable = Table.ExpandRecordColumn(
                                           DataResourcesAsTable, 
                                           "ResourceProperties", 
                                           {
                                               "profile",
                                               "name",
                                               "path",
                                               "__fullpath",
                                               "__pathtype",
                                               "title",
                                               "description",
                                               "format",
                                               "mediatype",
                                               "encoding",
                                               "bytes",
                                               "hash",
                                               "schema",
                                               "__resolvedschema",
                                               "dialect",
                                               "__resolveddialect",
                                               "sources",
                                               "licenses"
                                           }, 
                                           {
                                               "profile",
                                               "name",
                                               "path",
                                               "__fullpath",
                                               "__pathtype",
                                               "title",
                                               "description",
                                               "format",
                                               "mediatype",
                                               "encoding",
                                               "bytes",
                                               "hash",
                                               "schema",
                                               "__resolvedschema",
                                               "dialect",
                                               "__resolveddialect",
                                               "sources",
                                               "licenses"
                                           }
                                       ),
        // Add a column with the fully qualified resource path. If the resource path is not a fully qualified URL then it's treated as a relative path.
        ExpandedDataResourcesWithDataAsTable = Table.AddColumn(
                                                   Table.AddIndexColumn(ExpandedDataResourcesAsTable, "index", 0, 1), 
                                                   "data", 
                                                   // The file extension check needs to work on a path that is text or a list (i.e. a path property with multiple data files)
                                                   each if [path] is list then
                                                          if Text.Contains([path]{0}, ".csv") or Text.Contains([path]{0}, ".csv.gz") then
                                                              DataPackage.Table(dataPackageIdentifier, [index], null, ignoreTableSchemaTypes)
                                                          else 
                                                              null
                                                        else
                                                            if Text.Contains([path], ".csv") or Text.Contains([path], ".csv.gz") then
                                                              DataPackage.Table(dataPackageIdentifier, [index], null, ignoreTableSchemaTypes)
                                                        else 
                                                            null
                                               ),
        ExpandedDataResourcesWithDataAsBufferedTable = Table.Buffer(ExpandedDataResourcesWithDataAsTable),
        
        DataTables = // Project the Data Package properties as columns.
                     Table.SelectColumns(
                         ExpandedDataResourcesWithDataAsBufferedTable, 
                         {
                             "index", 
                             "data",
                             "profile",
                             "name",
                             "path",
                             "__fullpath",
                             "__pathtype",
                             "title",
                             "description",
                             "format",
                             "mediatype",
                             "encoding",
                             "bytes",
                             "hash",
                             "schema",
                             "__resolvedschema",
                             "dialect",
                             "__resolveddialect",
                             "sources",
                             "licenses"
                         }
                     )                      
    in
        DataTables,

    // Add documentation
    DataPackage.TablesWithDocumentation = type function (
                                   dataPackageIdentifier as (
                                       type text meta [
                                           Documentation.FieldCaption = "Data Package Identifier",
                                           Documentation.FieldDescription = "A valid Data Package Identifier",
                                           Documentation.SampleValues = {"https://datahub.io/core/gdp/datapackage.json"}
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
                                   Documentation.Name = "DataPackage.Tables",
                                   Documentation.LongDescription = "Returns a <code>table</code> that lists the Data Resources contained within a Data Package.
                                                                   <br><br>Example:
                                                                   <br>
                                                                   <br>
                                                                   <code>let
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;// Setup the shared function reference
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;DataPackage.Tables = DataPackageTables,
                                                                   <br>
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;// Invoke the function
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;Source = DataPackage.Tables(""https://datahub.io/core/gdp/datapackage.json"")
                                                                   <br>in
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;Source</code>
                                                                   <br>
                                                                   <br>
                                                                   More documentation available at: https://github.com/nimblelearn/datapackage-m",
                                   Documentation.Examples = null
                               ]
in
    Value.ReplaceType(DataPackage.Tables, DataPackage.TablesWithDocumentation)