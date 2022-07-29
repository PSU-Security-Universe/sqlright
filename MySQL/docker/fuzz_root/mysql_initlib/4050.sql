SET NAMES utf8;
CREATE FUNCTION icu_major_version() RETURNS INT RETURN regexp_replace(icu_version(), '([[:digit:]]+)\..*', '$1');
DROP FUNCTION icu_major_version;
SELECT regexp_like( 'abc\n123\n456\nxyz\n', '(?m)^\\d+\\R\\d+$' );
SELECT regexp_like( 'a\nb', '(*CR)a.b' );
SELECT regexp_like( 'a\nb', 'a\\vb' );
