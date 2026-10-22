part of 'app_database.dart';

// SQLite's worker parses legacy JSON. Only rendering metadata crosses into Dart:
// no ent.data, attachment base64, headers or unknown payload fields are selected.
final _searchProjection =
    '''
  CASE WHEN m.hidden OR m.deleted OR NOT json_valid(m.content) THEN ''
    WHEN json_type(m.content)='text' THEN json_extract(m.content, '\$')
    WHEN json_type(m.content, '\$.txt')='text'
      THEN json_extract(m.content, '\$.txt') ELSE '' END AS text,
  CASE WHEN m.hidden OR m.deleted OR NOT json_valid(m.content) THEN '[]'
    WHEN json_type(m.content, '\$.fmt')='array' THEN (
      SELECT json_group_array(json_object(
        'at', ${_searchNumber('at', -2)},
        'len', ${_searchNumber('len', -1)},
        'tp', $_searchFormatType,
        'key', ${_searchNumber('key', -1)}
      )) FROM json_each(m.content, '\$.fmt') f
    ) ELSE '[]' END AS formats,
  CASE WHEN m.hidden OR m.deleted OR NOT json_valid(m.content) THEN '[]'
    WHEN json_type(m.content, '\$.ent')='array' THEN (
      SELECT json_group_array(CASE WHEN e.type='object' THEN CASE
        WHEN json_type(e.value, '\$.tp')='text' AND
          json_extract(e.value, '\$.tp') IN ('HD','QQ','QR','IM','AU','VD','BR')
        THEN json_extract(e.value, '\$.tp') END END)
      FROM json_each(m.content, '\$.ent') e
    ) ELSE '[]' END AS types
''';

// Invalid numeric fields must stay invalid, not become Drafty's default zero.
String _searchNumber(String field, int invalid) =>
    '''
  CASE WHEN f.type='object' THEN CASE
    WHEN json_type(f.value, '\$.$field') IN ('integer','real')
      THEN json_extract(f.value, '\$.$field')
    WHEN json_type(f.value, '\$.$field') IS NULL OR
      json_type(f.value, '\$.$field')='null' THEN NULL
    ELSE $invalid END ELSE $invalid END
''';

// Only these types affect visible text. Unknown string types remain nonempty;
// malformed types remain invalid so they cannot fall back to an entity key.
const _searchFormatType = '''
  CASE WHEN f.type='object' THEN CASE
    WHEN json_type(f.value, '\$.tp') IS NULL OR
      json_type(f.value, '\$.tp')='null' THEN NULL
    WHEN json_type(f.value, '\$.tp')<>'text' THEN ''
    WHEN json_extract(f.value, '\$.tp') IN ('HD','QQ','QR','IM','AU','VD','BR','')
      THEN json_extract(f.value, '\$.tp')
    ELSE '?' END ELSE '' END
''';
