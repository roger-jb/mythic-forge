ace.define("ace/theme/tomorrow_night",["require","exports","module","ace/lib/dom"],function(e,t,n){t.isDark=!0,t.cssClass="ace-tomorrow-night",t.cssText=".ace-tomorrow-night .ace_gutter {\n  background: #25282c;\n  color: #C5C8C6\n}\n\n.ace-tomorrow-night .ace_print-margin {\n  width: 1px;\n  background: #25282c\n}\n\n.ace-tomorrow-night .ace_scroller {\n  background-color: #1D1F21\n}\n\n.ace-tomorrow-night .ace_text-layer {\n  color: #C5C8C6\n}\n\n.ace-tomorrow-night .ace_cursor {\n  border-left: 2px solid #AEAFAD\n}\n\n.ace-tomorrow-night .ace_cursor.ace_overwrite {\n  border-left: 0px;\n  border-bottom: 1px solid #AEAFAD\n}\n\n.ace-tomorrow-night .ace_marker-layer .ace_selection {\n  background: #373B41\n}\n\n.ace-tomorrow-night.ace_multiselect .ace_selection.ace_start {\n  box-shadow: 0 0 3px 0px #1D1F21;\n  border-radius: 2px\n}\n\n.ace-tomorrow-night .ace_marker-layer .ace_step {\n  background: rgb(102, 82, 0)\n}\n\n.ace-tomorrow-night .ace_marker-layer .ace_bracket {\n  margin: -1px 0 0 -1px;\n  border: 1px solid #4B4E55\n}\n\n.ace-tomorrow-night .ace_marker-layer .ace_active-line {\n  background: #282A2E\n}\n\n.ace-tomorrow-night .ace_gutter-active-line {\n  background-color: #282A2E\n}\n\n.ace-tomorrow-night .ace_marker-layer .ace_selected-word {\n  border: 1px solid #373B41\n}\n\n.ace-tomorrow-night .ace_invisible {\n  color: #4B4E55\n}\n\n.ace-tomorrow-night .ace_keyword,\n.ace-tomorrow-night .ace_meta,\n.ace-tomorrow-night .ace_storage,\n.ace-tomorrow-night .ace_storage.ace_type,\n.ace-tomorrow-night .ace_support.ace_type {\n  color: #B294BB\n}\n\n.ace-tomorrow-night .ace_keyword.ace_operator {\n  color: #8ABEB7\n}\n\n.ace-tomorrow-night .ace_constant.ace_character,\n.ace-tomorrow-night .ace_constant.ace_language,\n.ace-tomorrow-night .ace_constant.ace_numeric,\n.ace-tomorrow-night .ace_keyword.ace_other.ace_unit,\n.ace-tomorrow-night .ace_support.ace_constant,\n.ace-tomorrow-night .ace_variable.ace_parameter {\n  color: #DE935F\n}\n\n.ace-tomorrow-night .ace_constant.ace_other {\n  color: #CED1CF\n}\n\n.ace-tomorrow-night .ace_invalid {\n  color: #CED2CF;\n  background-color: #DF5F5F\n}\n\n.ace-tomorrow-night .ace_invalid.ace_deprecated {\n  color: #CED2CF;\n  background-color: #B798BF\n}\n\n.ace-tomorrow-night .ace_fold {\n  background-color: #81A2BE;\n  border-color: #C5C8C6\n}\n\n.ace-tomorrow-night .ace_entity.ace_name.ace_function,\n.ace-tomorrow-night .ace_support.ace_function,\n.ace-tomorrow-night .ace_variable {\n  color: #81A2BE\n}\n\n.ace-tomorrow-night .ace_support.ace_class,\n.ace-tomorrow-night .ace_support.ace_type {\n  color: #F0C674\n}\n\n.ace-tomorrow-night .ace_markup.ace_heading,\n.ace-tomorrow-night .ace_string {\n  color: #B5BD68\n}\n\n.ace-tomorrow-night .ace_entity.ace_name.ace_tag,\n.ace-tomorrow-night .ace_entity.ace_other.ace_attribute-name,\n.ace-tomorrow-night .ace_meta.ace_tag,\n.ace-tomorrow-night .ace_string.ace_regexp,\n.ace-tomorrow-night .ace_variable {\n  color: #CC6666\n}\n\n.ace-tomorrow-night .ace_comment {\n  color: #969896\n}\n\n.ace-tomorrow-night .ace_markup.ace_underline {\n  text-decoration: underline\n}\n\n.ace-tomorrow-night .ace_indent-guide {\n  background: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAACCAYAAACZgbYnAAAAEklEQVQImWOQlVf8z7Bq1ar/AA/hBFp7egmpAAAAAElFTkSuQmCC) right repeat-y\n}";var r=e("../lib/dom");r.importCssString(t.cssText,t.cssClass)})