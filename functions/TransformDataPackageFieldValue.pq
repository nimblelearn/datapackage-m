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

//Attempt to coerce JSON Table Schema field type values into appropriate M type values
(
  FieldType as text,
  FieldValue as any
) as any =>
let 
  InputValue = Text.From(FieldValue),
  OutputValue = if FieldType = "string" 
                  then InputValue 
                else if FieldType = "number" then 
                  Number.From(InputValue)
                else if FieldType = "integer" then 
                  Number.From(InputValue)
                else if FieldType = "boolean" then 
                  if Text.Lower(InputValue) = "yes"
                    or Text.Lower(InputValue) = "y"
                    or Text.Lower(InputValue) = "true"
                    or Text.Lower(InputValue) = "t"
                    or Text.Lower(InputValue) = "1"
                  then 
                    true
                  else if Text.Lower(InputValue) = "no"
                    or Text.Lower(InputValue) = "n"
                    or Text.Lower(InputValue) = "false"
                    or Text.Lower(InputValue) = "f"
                    or Text.Lower(InputValue) = "0"
                  then 
                    false
                  else InputValue 
                else if FieldType = "object" 
                  or FieldType = "array" 
                then 
                  Json.Document(InputValue) 
                else if FieldType = "date" then 
                  Date.From(InputValue)  
                else if FieldType = "datetime" then 
                  DateTime.From(InputValue)
                else if FieldType = "time" then 
                  Time.From(InputValue)
                //Any field types that are not handled yet
                else InputValue
in
  OutputValue