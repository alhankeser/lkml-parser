include: "/asdf/{{{{{asdf/'include' 1"
include: '/asdf/asdf/"include" 2'

view: orders {
  label: "Orders label"
  extension: "extension value"
  sql_table_name: "sqlTableName value"
  drill_fields: "drillFields value"
  suggestions: Yes
  fields_hidden_by_default: No
  extends: [extendsval1, extendsval2]
  required_access_grants: ["requiredAccessGrantsVal1", 
        "requiredAccessGrantsVal2"]
  derived_table: {
    sql: select *
      from mytable
      ${asdfasfd}



      
      ;;
  }

  dimension: dim_name {
    label: "hello"
    sql: something ${asdfasfd}
      with a dimension: wrong" in it 
      and ' also a view: fail ' 
      ;;
    type: string
  }

  dimension: dim_name2 {
    label: "hello"
    sql: ${asdfasfd};;
    type: string
  }

  measure: ct {
    value_format_name: decimal_2
    drill_fields: [one, "two", 
    three, 'four']
  }
}
