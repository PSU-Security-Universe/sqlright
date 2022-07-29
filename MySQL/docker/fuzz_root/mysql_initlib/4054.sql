SET NAMES utf8;
CREATE FUNCTION icu_major_version() RETURNS INT RETURN regexp_replace(icu_version(), '([[:digit:]]+)\..*', '$1');
DROP FUNCTION icu_major_version;
SELECT regexp_like('', "(((((((){120}){11}){11}){11}){80}){11}){4}" );
