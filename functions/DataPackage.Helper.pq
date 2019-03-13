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

// A function that returns a Data Package helper function 
let
    DataPackage.Helper = (functionName as text) as function =>
    let
        /*
        Resolve a Data Package Identifier and return the Data Package metadata as a record along with some inferred helper properties. 
        The inferred helper properties are prefixed with a double underscore e.g. '__fullpath'.
        */ 
        DataPackage.Package = (dataPackageIdentifier as text) as record =>
        let               
            // Base path pattern to use when resolving Data Package names against the Core Data Package registry
            CoreRegistryBasePathPattern = "https://datahub.io/core/{name}/",
        
            // The data package spec states that the descriptor file MUST be named datapackage.json
            Descriptor = "datapackage.json",
        
            // Expand the path if needed. This is a preliminary step for resolving the Data Package identifier.
            ExpandedPath = if Text.Contains(dataPackageIdentifier, "\") = false and Text.Contains(dataPackageIdentifier, "/") = false then
                               // Treat this as an identifier for a Data Package in the Core datasets registry on datahub.io
                               Text.Replace(CoreRegistryBasePathPattern, "{name}", dataPackageIdentifier)
                           // Resolve the github.com URL to the corresponding raw.githubusercontent.com URL
                           else if Text.Contains(dataPackageIdentifier,"github.com") then
                                   Text.Replace(
                                       Text.Replace(
                                           Text.Replace(
                                               dataPackageIdentifier, 
                                               "github.com", 
                                               "raw.githubusercontent.com"
                                           ), 
                                           "/blob/master", 
                                           "/master"
                                       ),
                                    "/tree/master",
                                    "/master"
                                   )
                           else 
                               dataPackageIdentifier,
        
            // Build the base path for the Data Package
            BasePath = Text.Replace(
                           if Text.StartsWith(ExpandedPath, "http") then 
                               (
                                   if Text.End(ExpandedPath, 1) <> "/" and Text.Contains(ExpandedPath, "datapackage.json") = false then 
                                       ExpandedPath & "/" 
                                   else 
                                       ExpandedPath
                               )
                           else 
                               (
                                   if Text.End(ExpandedPath, 1) <> "\" and Text.Contains(ExpandedPath, "datapackage.json") = false then 
                                       ExpandedPath & "\" 
                                   else 
                                       ExpandedPath
                               ),
                           "datapackage.json", 
                           ""
                      ),
        
            // Build the fully qualified path of the descriptor file
            DescriptorPath = BasePath & Descriptor,
        
            // Infer the Data Package location type
            DescriptorPathType = if Text.StartsWith(DescriptorPath, "http") then
                           "remote"
                       else
                           "local",                
            
            // Deserialise the Data Package metadata into a record
            DataPackage = Json.Document(DataPackage.ResourceContents(DescriptorPath, DescriptorPathType)),
            
            AddResourcePathType = (path as any) => 
                let 
                    Path = if path is list then
                               // The path type must be of a single type when data is split across multiple files, so we only need to consider the first path in the list
                               path{0}
                           else
                               path,
                    PathType = if Text.StartsWith(Path, "http") then
                                   // The path is remote
                                   "remote"
                               else
                                   // Inherit the DataPackage descriptor path type
                                   DescriptorPathType
                in
                    PathType,
            
            AddResourceFullPath = (pathOuter as any, pathTypeOuter as text, descriptorPathTypeOuter as text) =>
                let
                    // Get the fully qualified file path
                    GetFullPath = (path as text, pathType as text, descriptorPathType as text) =>
                    let
                        // Flag whether the path is absolute or relative
                        IsRelativePath = if Text.StartsWith(path, "http") then
                                             // This is an absolute path i.e. a URL
                                             false
                                         else
                                            // This is a relative path and should inherit the base path of the DataPackage descriptor
                                             true,
        
                        AbsolutePath = if pathType = "remote" and IsRelativePath = false then
                                           // No resolution required; the path is already absolute
                                           path
                                       else if pathType = "remote" and IsRelativePath = true then
                                           // Resolve the relative remote path to an absolute URL
                                           BasePath & path
                                       else if pathType = "local" and IsRelativePath = true then
                                           // Resolve the relative local path to an absolute Windows file location
                                           BasePath & Text.Replace(path, "/", "\")
                                       else 
                                           try error "Unhandled path type."
                    in
                        AbsolutePath,
        
                    FullPath = if pathOuter is list then
                                   // The path type must be the same when data is split across files
                                   List.Transform(pathOuter, each GetFullPath(_, pathTypeOuter, descriptorPathTypeOuter))
                               else
                                   GetFullPath(pathOuter, pathTypeOuter, descriptorPathTypeOuter)
                in
                    FullPath,   
        
            // Resolve the schema descriptor. It may be inline or a reference to the location of a schema descriptor.          
            AddResourceResolveSchema = (schema as any) => if schema is record then
                                                              // The schema object is already present; no resolution is required.
                                                              schema
                                                          // Treat this as a reference to a schema in a remote location 
                                                          else if schema is text then
                                                              // The schema property points to an external schema descriptor; resolution is required.
                                                              Json.Document(DataPackage.ResourceContents(schema, "remote"))
                                                          else
                                                              try error "The schema property is not valid.", 
        
            // Resolve the dialect descriptor. It may be inline or a reference to the location of a dialect descriptor             
            AddResourceResolveDialect = (dialect as any) => if dialect is record or dialect = null then
                                                   // The dialect object is already present; no resolution is required
                                                   dialect
                                               // The assumption has been made that reference will be to a dialect in a remote location 
                                               else if dialect is text then
                                                   // The dialect property points to an external dialect descriptor; resolution is required.
                                                   Json.Document(DataPackage.ResourceContents(dialect, "remote"))
                                               else
                                                   try error "The dialect property is not valid.", 
        
            // Extend the Data Package record with the inferred fields (i.e. properties)
            ExtendedResources = [
                                    resources = List.Transform(
                                                    DataPackage[resources],
                                                    each Record.Combine(
                                                             {
                                                                 _,
                                                                 [ 
                                                                     __pathtype = AddResourcePathType([path]),                                                             
                                                                     __fullpath = AddResourceFullPath([path], __pathtype, descriptorpathtype),
                                                                     __resolvedschema = AddResourceResolveSchema([schema]?),                                         
                                                                     __resolveddialect = AddResourceResolveDialect([dialect]?)                                        
                                                                 ]
                                                             }
                                                         )
                                                ),
                                    descriptorpathtype = DescriptorPathType 
                                ],
            
            // Rename the original 'resources' field to 'replacedresources' so that it can still be accessed in its unaltered state                   
            ExtendedDataPackage = Record.Combine(
                                      {
                                          Record.RenameFields(DataPackage, {"resources", "replacedresources"}), 
                                          ExtendedResources
                                      }
                                  )
        in
            ExtendedDataPackage,   
        
        // Returns the data content of a Data Resource. If the file is Gzip compressed, it will be decompressed.
        DataPackage.ResourceContents = (path as text, pathType as text, optional compression as text) =>
        let
            PathType = Text.Lower(pathType),
            Compression = if compression = null then
                              "none"
                          else 
                              Text.Lower(compression),

            // Working around the limitation of the Power BI service not supporting data refresh when Web.Contents is used with a fully dynamic URL.
            // See this Power BI Idea: https://ideas.powerbi.com/forums/265200-power-bi-ideas/suggestions/10927416-web-contents-should-support-scheduled-refresh-ev.
            // This workaround will be applied by in a future release.
            /*WebContents = Web.Contents(
                              "https://datapackage-m-redirector.azurewebsites.net",
                              [RelativePath = "?redirect=" & path]
                          ),*/

            WebContents = Web.Contents(path),

            FileContents = File.Contents(path),
            CompressionErrorMessage = "Unsupported compression type. Allowed values: ""none"", ""gz"".",
            PathTypeErrorMessage = "Unsupported path type. Allowed values: ""remote"", ""local"".",
            Contents = if PathType = "remote" then
                           if Compression = "none" then
                               WebContents
                           else if Compression = "gz" then
                               Binary.Decompress(WebContents, Compression.GZip)
                           else
                               try error CompressionErrorMessage
                       else if PathType = "local" then
                           if Compression = "none" then
                               FileContents
                           else if Compression = "gz" then
                               Binary.Decompress(FileContents, Compression.GZip)
                           else
                               try error CompressionErrorMessage
                       else
                           try error PathTypeErrorMessage
        in
            Contents,
        
        // Returns the untyped Data Resource (no Table Schema applied) after using the Data Package metadata to determine how the data should be parsed.
        DataPackage.Resource = (dataResource as record) as table => 
        let
            // Get the fully qualified file path. This property will only exist if the data is not inline
            Path = dataResource[__fullpath]?,
        
            // If the data is inline then the tabular data will be represented as JSON in the 'data' property
            Data = dataResource[data]?,
        
            // Determine whether special handling of multiple data file paths is required: http://frictionlessdata.io/specs/data-resource/
            MultipleDataFilePath = Path is list,
          
            PathType = dataResource[__pathtype],
                 
            // Map valid dataResource fields to variables
            Header = if (dataResource[__resolveddialect]?)[header]? = null then 
                         if (dataResource[dialect]?)[header]? = null  then
                             true
                         else
                             (dataResource[dialect]?)[header]?
                     else 
                         (dataResource[__resolveddialect]?)[header]?,              
        
            // The handling of the compression property isn't defined by the spec so this may need to be reworked in the near-future.
            InferredExtension = if MultipleDataFilePath then
                                    Text.Range(Path{0}, Text.PositionOf(Path{0}, ".", Occurrence.Last) + 1)
                                else
                                    Text.Range(Path, Text.PositionOf(Path, ".", Occurrence.Last) + 1),
            InferredCompression = if List.Contains({"csv", "txt"}, InferredExtension) then
                                      "none"
                                  else
                                      InferredExtension,
            Compression = if dataResource[compression]? = null then
                              InferredCompression               
                          else
                              dataResource[compression]?,
        
            Delimiter = if dataResource[delimiter]? = null then 
                            "," 
                        else 
                            dataResource[delimiter]?,
        
            Encoding = if dataResource[encoding]? = null then 
                           65001 // UTF-8
                       else
                           // TODO: Needs mapping from valid codes (http://www.iana.org/assignments/character-sets/character-sets.xhtml) to M equivalents. This property is currently ignored and UTF-8 is always used.
                           65001 /*dataResource[encoding]?*/,
        
            DocumentOptions = [
                                  Delimiter = Delimiter, 
                                  Encoding = Encoding
                              ],
          
            LoadCsvFile = (path as text) => 
                          Csv.Document(
                              DataPackage.ResourceContents(
                                  path, 
                                  PathType, 
                                  Compression
                              ), 
                              DocumentOptions
                          ),
            
            LoadInlineJSON = (data as text) => 
                             let
                                 JsonTabularData = Json.Document(data),
                                 TabularDataRowType = if JsonTabularData is list and JsonTabularData{0}? is list then
                                                          "arrays"
                                                      else if JsonTabularData is list and JsonTabularData{0}? is record then
                                                          "objects"
                                                      else
                                                          try error "Invalid JSON Tabular Data",
                                 DataTable = if TabularDataRowType = "arrays" then
                                                 #table(
                                                     JsonTabularData{0},
                                                     List.RemoveFirstN(JsonTabularData, 1)
                                                 )
                                               else if TabularDataRowType = "objects" then
                                                   Table.FromRecords(JsonTabularData)
                                               else
                                                   try error "Invalid JSON Tabular Data"
                             in
                                 DataTable,
        
            // Load the data from a CSV file or inline JSON depending on whether the 'path' or 'data' property has a value                                 
            LoadedData = if Path <> null then
                             if MultipleDataFilePath then
                                 Table.Combine(
                                     List.Transform(
                                         Path,
                                         each LoadCsvFile(_)
                                     )
                                 )
                             else
                                 LoadCsvFile(Path)
                         else
                             // The JSON Tabular Data specifies the header so the 'promote to header' step isn't needed
                             LoadInlineJSON(Data),
        
            DataTable = if Header = true and Data = null then 
                              Table.PromoteHeaders(LoadedData)
                          else 
                              LoadedData
        in
            DataTable,
    
        // Attempt to convert Table Schema field type values into appropriate M type values
        DataPackage.ConvertFieldValue = (fieldType as text, fieldValue as any) as any =>
        let 
            FieldTypeAsText = Text.From(fieldValue),
            MTypeValue = if fieldType = "string" then 
                             FieldTypeAsText 
                         else if fieldType = "number" then 
                             Number.From(FieldTypeAsText)
                         else if fieldType = "integer" then 
                             Number.From(FieldTypeAsText)
                         else if fieldType = "boolean" then 
                             if List.Contains({"yes", "y", "true", "t", "1"}, Text.Lower(FieldTypeAsText)) then 
                                 true
                             else if List.Contains({"no", "n", "false", "f", "0"}, Text.Lower(FieldTypeAsText)) then 
                                 false
                             else 
                                 FieldTypeAsText 
                         else if fieldType = "object" or fieldType = "array" then 
                             Json.Document(FieldTypeAsText) 
                         else if fieldType = "date" then 
                             Date.From(FieldTypeAsText)  
                         else if fieldType = "datetime" then 
                             DateTime.From(FieldTypeAsText)
                         else if fieldType = "time" then 
                             Time.From(FieldTypeAsText)
                         // Any field types that are not handled yet
                         else 
                             FieldTypeAsText
        in
            MTypeValue,
    
        // Map JSON Table Schema field types to equivalent M types    
        DataPackage.ConvertFieldType = (fieldType as text) as text =>
        let
            MType = if fieldType = "string" then 
                        "text" 
                    else if List.Contains({"number", "date", "datetime", "time"}, fieldType) then 
                        fieldType 
                    else if fieldType = "integer" then
                        "number"
                    else if fieldType = "boolean" then
                        "logical"
                    else
                        "text"
        in 
            MType,
    
        // Map the requested Data Package helper functions to record fields
        HelperFunctions = [
                              DataPackage.Package = DataPackage.Package,
                              DataPackage.ResourceContents = DataPackage.ResourceContents,
                              DataPackage.Resource = DataPackage.Resource,
                              DataPackage.ConvertFieldType = DataPackage.ConvertFieldType,
                              DataPackage.ConvertFieldValue = DataPackage.ConvertFieldValue
                          ],
    
        // Return the requested helper function
        HelperFunction = Record.Field(HelperFunctions, functionName)
    in
        HelperFunction,
    // Add documentation
    DataPackage.HelperWithDocumentation = type function (
                                   functionName as (
                                       type text meta [
                                           Documentation.FieldCaption = "Function Name",
                                           Documentation.FieldDescription = "A valid Data Package helper function name",
                                           Documentation.SampleValues = {"DataPackage.Package"}
                                       ]
                                   )
                               ) as function meta [
                                   Documentation.Name = "DataPackage.Helper",
                                   Documentation.LongDescription = "Returns a Data Package helper function as a <code>function</code>.
                                                                   <br><br>Example:
                                                                   <br>
                                                                   <br>
                                                                   <code>let
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;// Setup the shared function reference
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;DataPackage.Helper = DataPackageHelper,
                                                                   <br>
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;// Get the required helper function by name
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;DataPackage.Package = DataPackage.Helper(""DataPackage.Package""),
                                                                   <br>
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;// Invoke the helper function
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;Source = DataPackage.Package(""https://datahub.io/core/gdp/datapackage.json"")
                                                                   <br>in
                                                                   <br>&nbsp;&nbsp;&nbsp;&nbsp;Source</code>
                                                                   <br>
                                                                   <br>
                                                                   More documentation available at: https://github.com/nimblelearn/datapackage-m",                                   
                                   Documentation.Examples = null
                               ]
in
    Value.ReplaceType(DataPackage.Helper, DataPackage.HelperWithDocumentation)