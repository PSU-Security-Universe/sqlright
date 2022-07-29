CREATE TABLE t1 (pk INTEGER PRIMARY KEY, i1 TINYINT, u1 TINYINT UNSIGNED, i2 SMALLINT, u2 SMALLINT UNSIGNED, i3 MEDIUMINT, u3 MEDIUMINT UNSIGNED, i4 INTEGER, u4 INTEGER UNSIGNED, i8 BIGINT, u8 BIGINT UNSIGNED);
INSERT INTO t1 VALUES (0, -128, 0, -32768, 0, -8388608, 0, -2147483648, 0, -9223372036854775808, 0), (1, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0), (2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1), (4, 127, 255, 32767, 65535, 8388607, 16777215, 2147483647, 4294967295, 9223372036854775807, 18446744073709551615);
set @iv= -9223372036854775809;
set @dv= -9223372036854775809.0;
set @fv= -9223372036854775809.0e0;
set @sv= "-9223372036854775809";
SELECT i1 = -9223372036854775809 AS a, u1 = -9223372036854775809 AS au, i2 = -9223372036854775809 AS b, u2 = -9223372036854775809 AS bu, i3 = -9223372036854775809 AS c, u3 = -9223372036854775809 AS cu, i4 = -9223372036854775809 AS d, u4 = -9223372036854775809 AS du, i8 = -9223372036854775809 AS e, u8 = -9223372036854775809 AS eu FROM t1;
prepare s1 from "SELECT i1 = ? AS a, u1 = ? AS au, i2 = ? AS b, u2 = ? AS bu, i3 = ? AS c, u3 = ? AS cu, i4 = ? AS d, u4 = ? AS du, i8 = ? AS e, u8 = ? AS eu FROM t1";
execute s1 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 = -9223372036854775809.0 AS a, u1 = -9223372036854775809.0 AS au, i2 = -9223372036854775809.0 AS b, u2 = -9223372036854775809.0 AS bu, i3 = -9223372036854775809.0 AS c, u3 = -9223372036854775809.0 AS cu, i4 = -9223372036854775809.0 AS d, u4 = -9223372036854775809.0 AS du, i8 = -9223372036854775809.0 AS e, u8 = -9223372036854775809.0 AS eu FROM t1;
prepare s1 from "SELECT i1 = ? AS a, u1 = ? AS au, i2 = ? AS b, u2 = ? AS bu, i3 = ? AS c, u3 = ? AS cu, i4 = ? AS d, u4 = ? AS du, i8 = ? AS e, u8 = ? AS eu FROM t1";
execute s1 using @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv;
SELECT i1 = -9223372036854775809.0e0 AS a, u1 = -9223372036854775809.0e0 AS au, i2 = -9223372036854775809.0e0 AS b, u2 = -9223372036854775809.0e0 AS bu, i3 = -9223372036854775809.0e0 AS c, u3 = -9223372036854775809.0e0 AS cu, i4 = -9223372036854775809.0e0 AS d, u4 = -9223372036854775809.0e0 AS du, i8 = -9223372036854775809.0e0 AS e, u8 = -9223372036854775809.0e0 AS eu FROM t1;
prepare s1 from "SELECT i1 = ? AS a, u1 = ? AS au, i2 = ? AS b, u2 = ? AS bu, i3 = ? AS c, u3 = ? AS cu, i4 = ? AS d, u4 = ? AS du, i8 = ? AS e, u8 = ? AS eu FROM t1";
execute s1 using @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv;
SELECT i1 = '-9223372036854775809' AS a, u1 = '-9223372036854775809' AS au, i2 = '-9223372036854775809' AS b, u2 = '-9223372036854775809' AS bu, i3 = '-9223372036854775809' AS c, u3 = '-9223372036854775809' AS cu, i4 = '-9223372036854775809' AS d, u4 = '-9223372036854775809' AS du, i8 = '-9223372036854775809' AS e, u8 = '-9223372036854775809' AS eu FROM t1;
prepare s1 from "SELECT i1 = ? AS a, u1 = ? AS au, i2 = ? AS b, u2 = ? AS bu, i3 = ? AS c, u3 = ? AS cu, i4 = ? AS d, u4 = ? AS du, i8 = ? AS e, u8 = ? AS eu FROM t1";
execute s1 using @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv;
SELECT i1 <> -9223372036854775809 AS a, u1 <> -9223372036854775809 AS au, i2 <> -9223372036854775809 AS b, u2 <> -9223372036854775809 AS bu, i3 <> -9223372036854775809 AS c, u3 <> -9223372036854775809 AS cu, i4 <> -9223372036854775809 AS d, u4 <> -9223372036854775809 AS du, i8 <> -9223372036854775809 AS e, u8 <> -9223372036854775809 AS eu FROM t1;
prepare s2 from "SELECT i1 <> ? AS a, u1 <> ? AS au, i2 <> ? AS b, u2 <> ? AS bu, i3 <> ? AS c, u3 <> ? AS cu, i4 <> ? AS d, u4 <> ? AS du, i8 <> ? AS e, u8 <> ? AS eu FROM t1";
execute s2 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 <> -9223372036854775809.0 AS a, u1 <> -9223372036854775809.0 AS au, i2 <> -9223372036854775809.0 AS b, u2 <> -9223372036854775809.0 AS bu, i3 <> -9223372036854775809.0 AS c, u3 <> -9223372036854775809.0 AS cu, i4 <> -9223372036854775809.0 AS d, u4 <> -9223372036854775809.0 AS du, i8 <> -9223372036854775809.0 AS e, u8 <> -9223372036854775809.0 AS eu FROM t1;
prepare s2 from "SELECT i1 <> ? AS a, u1 <> ? AS au, i2 <> ? AS b, u2 <> ? AS bu, i3 <> ? AS c, u3 <> ? AS cu, i4 <> ? AS d, u4 <> ? AS du, i8 <> ? AS e, u8 <> ? AS eu FROM t1";
execute s2 using @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv;
SELECT i1 <> -9223372036854775809.0e0 AS a, u1 <> -9223372036854775809.0e0 AS au, i2 <> -9223372036854775809.0e0 AS b, u2 <> -9223372036854775809.0e0 AS bu, i3 <> -9223372036854775809.0e0 AS c, u3 <> -9223372036854775809.0e0 AS cu, i4 <> -9223372036854775809.0e0 AS d, u4 <> -9223372036854775809.0e0 AS du, i8 <> -9223372036854775809.0e0 AS e, u8 <> -9223372036854775809.0e0 AS eu FROM t1;
prepare s2 from "SELECT i1 <> ? AS a, u1 <> ? AS au, i2 <> ? AS b, u2 <> ? AS bu, i3 <> ? AS c, u3 <> ? AS cu, i4 <> ? AS d, u4 <> ? AS du, i8 <> ? AS e, u8 <> ? AS eu FROM t1";
execute s2 using @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv;
SELECT i1 <> '-9223372036854775809' AS a, u1 <> '-9223372036854775809' AS au, i2 <> '-9223372036854775809' AS b, u2 <> '-9223372036854775809' AS bu, i3 <> '-9223372036854775809' AS c, u3 <> '-9223372036854775809' AS cu, i4 <> '-9223372036854775809' AS d, u4 <> '-9223372036854775809' AS du, i8 <> '-9223372036854775809' AS e, u8 <> '-9223372036854775809' AS eu FROM t1;
prepare s2 from "SELECT i1 <> ? AS a, u1 <> ? AS au, i2 <> ? AS b, u2 <> ? AS bu, i3 <> ? AS c, u3 <> ? AS cu, i4 <> ? AS d, u4 <> ? AS du, i8 <> ? AS e, u8 <> ? AS eu FROM t1";
execute s2 using @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv;
SELECT i1 < -9223372036854775809 AS a, u1 < -9223372036854775809 AS au, i2 < -9223372036854775809 AS b, u2 < -9223372036854775809 AS bu, i3 < -9223372036854775809 AS c, u3 < -9223372036854775809 AS cu, i4 < -9223372036854775809 AS d, u4 < -9223372036854775809 AS du, i8 < -9223372036854775809 AS e, u8 < -9223372036854775809 AS eu FROM t1;
prepare s3 from "SELECT i1 < ? AS a, u1 < ? AS au, i2 < ? AS b, u2 < ? AS bu, i3 < ? AS c, u3 < ? AS cu, i4 < ? AS d, u4 < ? AS du, i8 < ? AS e, u8 < ? AS eu FROM t1";
execute s3 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 < -9223372036854775809.0 AS a, u1 < -9223372036854775809.0 AS au, i2 < -9223372036854775809.0 AS b, u2 < -9223372036854775809.0 AS bu, i3 < -9223372036854775809.0 AS c, u3 < -9223372036854775809.0 AS cu, i4 < -9223372036854775809.0 AS d, u4 < -9223372036854775809.0 AS du, i8 < -9223372036854775809.0 AS e, u8 < -9223372036854775809.0 AS eu FROM t1;
prepare s3 from "SELECT i1 < ? AS a, u1 < ? AS au, i2 < ? AS b, u2 < ? AS bu, i3 < ? AS c, u3 < ? AS cu, i4 < ? AS d, u4 < ? AS du, i8 < ? AS e, u8 < ? AS eu FROM t1";
execute s3 using @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv;
SELECT i1 < -9223372036854775809.0e0 AS a, u1 < -9223372036854775809.0e0 AS au, i2 < -9223372036854775809.0e0 AS b, u2 < -9223372036854775809.0e0 AS bu, i3 < -9223372036854775809.0e0 AS c, u3 < -9223372036854775809.0e0 AS cu, i4 < -9223372036854775809.0e0 AS d, u4 < -9223372036854775809.0e0 AS du, i8 < -9223372036854775809.0e0 AS e, u8 < -9223372036854775809.0e0 AS eu FROM t1;
prepare s3 from "SELECT i1 < ? AS a, u1 < ? AS au, i2 < ? AS b, u2 < ? AS bu, i3 < ? AS c, u3 < ? AS cu, i4 < ? AS d, u4 < ? AS du, i8 < ? AS e, u8 < ? AS eu FROM t1";
execute s3 using @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv;
SELECT i1 < '-9223372036854775809' AS a, u1 < '-9223372036854775809' AS au, i2 < '-9223372036854775809' AS b, u2 < '-9223372036854775809' AS bu, i3 < '-9223372036854775809' AS c, u3 < '-9223372036854775809' AS cu, i4 < '-9223372036854775809' AS d, u4 < '-9223372036854775809' AS du, i8 < '-9223372036854775809' AS e, u8 < '-9223372036854775809' AS eu FROM t1;
prepare s3 from "SELECT i1 < ? AS a, u1 < ? AS au, i2 < ? AS b, u2 < ? AS bu, i3 < ? AS c, u3 < ? AS cu, i4 < ? AS d, u4 < ? AS du, i8 < ? AS e, u8 < ? AS eu FROM t1";
execute s3 using @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv;
SELECT i1 >= -9223372036854775809 AS a, u1 >= -9223372036854775809 AS au, i2 >= -9223372036854775809 AS b, u2 >= -9223372036854775809 AS bu, i3 >= -9223372036854775809 AS c, u3 >= -9223372036854775809 AS cu, i4 >= -9223372036854775809 AS d, u4 >= -9223372036854775809 AS du, i8 >= -9223372036854775809 AS e, u8 >= -9223372036854775809 AS eu FROM t1;
prepare s4 from "SELECT i1 >= ? AS a, u1 >= ? AS au, i2 >= ? AS b, u2 >= ? AS bu, i3 >= ? AS c, u3 >= ? AS cu, i4 >= ? AS d, u4 >= ? AS du, i8 >= ? AS e, u8 >= ? AS eu FROM t1";
execute s4 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 >= -9223372036854775809.0 AS a, u1 >= -9223372036854775809.0 AS au, i2 >= -9223372036854775809.0 AS b, u2 >= -9223372036854775809.0 AS bu, i3 >= -9223372036854775809.0 AS c, u3 >= -9223372036854775809.0 AS cu, i4 >= -9223372036854775809.0 AS d, u4 >= -9223372036854775809.0 AS du, i8 >= -9223372036854775809.0 AS e, u8 >= -9223372036854775809.0 AS eu FROM t1;
prepare s4 from "SELECT i1 >= ? AS a, u1 >= ? AS au, i2 >= ? AS b, u2 >= ? AS bu, i3 >= ? AS c, u3 >= ? AS cu, i4 >= ? AS d, u4 >= ? AS du, i8 >= ? AS e, u8 >= ? AS eu FROM t1";
execute s4 using @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv;
SELECT i1 >= -9223372036854775809.0e0 AS a, u1 >= -9223372036854775809.0e0 AS au, i2 >= -9223372036854775809.0e0 AS b, u2 >= -9223372036854775809.0e0 AS bu, i3 >= -9223372036854775809.0e0 AS c, u3 >= -9223372036854775809.0e0 AS cu, i4 >= -9223372036854775809.0e0 AS d, u4 >= -9223372036854775809.0e0 AS du, i8 >= -9223372036854775809.0e0 AS e, u8 >= -9223372036854775809.0e0 AS eu FROM t1;
prepare s4 from "SELECT i1 >= ? AS a, u1 >= ? AS au, i2 >= ? AS b, u2 >= ? AS bu, i3 >= ? AS c, u3 >= ? AS cu, i4 >= ? AS d, u4 >= ? AS du, i8 >= ? AS e, u8 >= ? AS eu FROM t1";
execute s4 using @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv;
SELECT i1 >= '-9223372036854775809' AS a, u1 >= '-9223372036854775809' AS au, i2 >= '-9223372036854775809' AS b, u2 >= '-9223372036854775809' AS bu, i3 >= '-9223372036854775809' AS c, u3 >= '-9223372036854775809' AS cu, i4 >= '-9223372036854775809' AS d, u4 >= '-9223372036854775809' AS du, i8 >= '-9223372036854775809' AS e, u8 >= '-9223372036854775809' AS eu FROM t1;
prepare s4 from "SELECT i1 >= ? AS a, u1 >= ? AS au, i2 >= ? AS b, u2 >= ? AS bu, i3 >= ? AS c, u3 >= ? AS cu, i4 >= ? AS d, u4 >= ? AS du, i8 >= ? AS e, u8 >= ? AS eu FROM t1";
execute s4 using @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv;
SELECT i1 <= -9223372036854775809 AS a, u1 <= -9223372036854775809 AS au, i2 <= -9223372036854775809 AS b, u2 <= -9223372036854775809 AS bu, i3 <= -9223372036854775809 AS c, u3 <= -9223372036854775809 AS cu, i4 <= -9223372036854775809 AS d, u4 <= -9223372036854775809 AS du, i8 <= -9223372036854775809 AS e, u8 <= -9223372036854775809 AS eu FROM t1;
prepare s5 from "SELECT i1 <= ? AS a, u1 <= ? AS au, i2 <= ? AS b, u2 <= ? AS bu, i3 <= ? AS c, u3 <= ? AS cu, i4 <= ? AS d, u4 <= ? AS du, i8 <= ? AS e, u8 <= ? AS eu FROM t1";
execute s5 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 <= -9223372036854775809.0 AS a, u1 <= -9223372036854775809.0 AS au, i2 <= -9223372036854775809.0 AS b, u2 <= -9223372036854775809.0 AS bu, i3 <= -9223372036854775809.0 AS c, u3 <= -9223372036854775809.0 AS cu, i4 <= -9223372036854775809.0 AS d, u4 <= -9223372036854775809.0 AS du, i8 <= -9223372036854775809.0 AS e, u8 <= -9223372036854775809.0 AS eu FROM t1;
prepare s5 from "SELECT i1 <= ? AS a, u1 <= ? AS au, i2 <= ? AS b, u2 <= ? AS bu, i3 <= ? AS c, u3 <= ? AS cu, i4 <= ? AS d, u4 <= ? AS du, i8 <= ? AS e, u8 <= ? AS eu FROM t1";
execute s5 using @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv;
SELECT i1 <= -9223372036854775809.0e0 AS a, u1 <= -9223372036854775809.0e0 AS au, i2 <= -9223372036854775809.0e0 AS b, u2 <= -9223372036854775809.0e0 AS bu, i3 <= -9223372036854775809.0e0 AS c, u3 <= -9223372036854775809.0e0 AS cu, i4 <= -9223372036854775809.0e0 AS d, u4 <= -9223372036854775809.0e0 AS du, i8 <= -9223372036854775809.0e0 AS e, u8 <= -9223372036854775809.0e0 AS eu FROM t1;
prepare s5 from "SELECT i1 <= ? AS a, u1 <= ? AS au, i2 <= ? AS b, u2 <= ? AS bu, i3 <= ? AS c, u3 <= ? AS cu, i4 <= ? AS d, u4 <= ? AS du, i8 <= ? AS e, u8 <= ? AS eu FROM t1";
execute s5 using @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv;
SELECT i1 <= '-9223372036854775809' AS a, u1 <= '-9223372036854775809' AS au, i2 <= '-9223372036854775809' AS b, u2 <= '-9223372036854775809' AS bu, i3 <= '-9223372036854775809' AS c, u3 <= '-9223372036854775809' AS cu, i4 <= '-9223372036854775809' AS d, u4 <= '-9223372036854775809' AS du, i8 <= '-9223372036854775809' AS e, u8 <= '-9223372036854775809' AS eu FROM t1;
prepare s5 from "SELECT i1 <= ? AS a, u1 <= ? AS au, i2 <= ? AS b, u2 <= ? AS bu, i3 <= ? AS c, u3 <= ? AS cu, i4 <= ? AS d, u4 <= ? AS du, i8 <= ? AS e, u8 <= ? AS eu FROM t1";
execute s5 using @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv;
SELECT i1 > -9223372036854775809 AS a, u1 > -9223372036854775809 AS au, i2 > -9223372036854775809 AS b, u2 > -9223372036854775809 AS bu, i3 > -9223372036854775809 AS c, u3 > -9223372036854775809 AS cu, i4 > -9223372036854775809 AS d, u4 > -9223372036854775809 AS du, i8 > -9223372036854775809 AS e, u8 > -9223372036854775809 AS eu FROM t1;
prepare s6 from "SELECT i1 > ? AS a, u1 > ? AS au, i2 > ? AS b, u2 > ? AS bu, i3 > ? AS c, u3 > ? AS cu, i4 > ? AS d, u4 > ? AS du, i8 > ? AS e, u8 > ? AS eu FROM t1";
execute s6 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 > -9223372036854775809.0 AS a, u1 > -9223372036854775809.0 AS au, i2 > -9223372036854775809.0 AS b, u2 > -9223372036854775809.0 AS bu, i3 > -9223372036854775809.0 AS c, u3 > -9223372036854775809.0 AS cu, i4 > -9223372036854775809.0 AS d, u4 > -9223372036854775809.0 AS du, i8 > -9223372036854775809.0 AS e, u8 > -9223372036854775809.0 AS eu FROM t1;
prepare s6 from "SELECT i1 > ? AS a, u1 > ? AS au, i2 > ? AS b, u2 > ? AS bu, i3 > ? AS c, u3 > ? AS cu, i4 > ? AS d, u4 > ? AS du, i8 > ? AS e, u8 > ? AS eu FROM t1";
execute s6 using @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv;
SELECT i1 > -9223372036854775809.0e0 AS a, u1 > -9223372036854775809.0e0 AS au, i2 > -9223372036854775809.0e0 AS b, u2 > -9223372036854775809.0e0 AS bu, i3 > -9223372036854775809.0e0 AS c, u3 > -9223372036854775809.0e0 AS cu, i4 > -9223372036854775809.0e0 AS d, u4 > -9223372036854775809.0e0 AS du, i8 > -9223372036854775809.0e0 AS e, u8 > -9223372036854775809.0e0 AS eu FROM t1;
prepare s6 from "SELECT i1 > ? AS a, u1 > ? AS au, i2 > ? AS b, u2 > ? AS bu, i3 > ? AS c, u3 > ? AS cu, i4 > ? AS d, u4 > ? AS du, i8 > ? AS e, u8 > ? AS eu FROM t1";
execute s6 using @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv;
SELECT i1 > '-9223372036854775809' AS a, u1 > '-9223372036854775809' AS au, i2 > '-9223372036854775809' AS b, u2 > '-9223372036854775809' AS bu, i3 > '-9223372036854775809' AS c, u3 > '-9223372036854775809' AS cu, i4 > '-9223372036854775809' AS d, u4 > '-9223372036854775809' AS du, i8 > '-9223372036854775809' AS e, u8 > '-9223372036854775809' AS eu FROM t1;
prepare s6 from "SELECT i1 > ? AS a, u1 > ? AS au, i2 > ? AS b, u2 > ? AS bu, i3 > ? AS c, u3 > ? AS cu, i4 > ? AS d, u4 > ? AS du, i8 > ? AS e, u8 > ? AS eu FROM t1";
execute s6 using @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv;
set @iv= -9223372036854775808;
set @dv= -9223372036854775808.0;
set @fv= -9223372036854775808.0e0;
set @sv= "-9223372036854775808";
SELECT i1 = -9223372036854775808 AS a, u1 = -9223372036854775808 AS au, i2 = -9223372036854775808 AS b, u2 = -9223372036854775808 AS bu, i3 = -9223372036854775808 AS c, u3 = -9223372036854775808 AS cu, i4 = -9223372036854775808 AS d, u4 = -9223372036854775808 AS du, i8 = -9223372036854775808 AS e, u8 = -9223372036854775808 AS eu FROM t1;
prepare s1 from "SELECT i1 = ? AS a, u1 = ? AS au, i2 = ? AS b, u2 = ? AS bu, i3 = ? AS c, u3 = ? AS cu, i4 = ? AS d, u4 = ? AS du, i8 = ? AS e, u8 = ? AS eu FROM t1";
execute s1 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 = -9223372036854775808.0 AS a, u1 = -9223372036854775808.0 AS au, i2 = -9223372036854775808.0 AS b, u2 = -9223372036854775808.0 AS bu, i3 = -9223372036854775808.0 AS c, u3 = -9223372036854775808.0 AS cu, i4 = -9223372036854775808.0 AS d, u4 = -9223372036854775808.0 AS du, i8 = -9223372036854775808.0 AS e, u8 = -9223372036854775808.0 AS eu FROM t1;
prepare s1 from "SELECT i1 = ? AS a, u1 = ? AS au, i2 = ? AS b, u2 = ? AS bu, i3 = ? AS c, u3 = ? AS cu, i4 = ? AS d, u4 = ? AS du, i8 = ? AS e, u8 = ? AS eu FROM t1";
execute s1 using @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv;
SELECT i1 = -9223372036854775808.0e0 AS a, u1 = -9223372036854775808.0e0 AS au, i2 = -9223372036854775808.0e0 AS b, u2 = -9223372036854775808.0e0 AS bu, i3 = -9223372036854775808.0e0 AS c, u3 = -9223372036854775808.0e0 AS cu, i4 = -9223372036854775808.0e0 AS d, u4 = -9223372036854775808.0e0 AS du, i8 = -9223372036854775808.0e0 AS e, u8 = -9223372036854775808.0e0 AS eu FROM t1;
prepare s1 from "SELECT i1 = ? AS a, u1 = ? AS au, i2 = ? AS b, u2 = ? AS bu, i3 = ? AS c, u3 = ? AS cu, i4 = ? AS d, u4 = ? AS du, i8 = ? AS e, u8 = ? AS eu FROM t1";
execute s1 using @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv;
SELECT i1 = '-9223372036854775808' AS a, u1 = '-9223372036854775808' AS au, i2 = '-9223372036854775808' AS b, u2 = '-9223372036854775808' AS bu, i3 = '-9223372036854775808' AS c, u3 = '-9223372036854775808' AS cu, i4 = '-9223372036854775808' AS d, u4 = '-9223372036854775808' AS du, i8 = '-9223372036854775808' AS e, u8 = '-9223372036854775808' AS eu FROM t1;
prepare s1 from "SELECT i1 = ? AS a, u1 = ? AS au, i2 = ? AS b, u2 = ? AS bu, i3 = ? AS c, u3 = ? AS cu, i4 = ? AS d, u4 = ? AS du, i8 = ? AS e, u8 = ? AS eu FROM t1";
execute s1 using @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv;
SELECT i1 <> -9223372036854775808 AS a, u1 <> -9223372036854775808 AS au, i2 <> -9223372036854775808 AS b, u2 <> -9223372036854775808 AS bu, i3 <> -9223372036854775808 AS c, u3 <> -9223372036854775808 AS cu, i4 <> -9223372036854775808 AS d, u4 <> -9223372036854775808 AS du, i8 <> -9223372036854775808 AS e, u8 <> -9223372036854775808 AS eu FROM t1;
prepare s2 from "SELECT i1 <> ? AS a, u1 <> ? AS au, i2 <> ? AS b, u2 <> ? AS bu, i3 <> ? AS c, u3 <> ? AS cu, i4 <> ? AS d, u4 <> ? AS du, i8 <> ? AS e, u8 <> ? AS eu FROM t1";
execute s2 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 <> -9223372036854775808.0 AS a, u1 <> -9223372036854775808.0 AS au, i2 <> -9223372036854775808.0 AS b, u2 <> -9223372036854775808.0 AS bu, i3 <> -9223372036854775808.0 AS c, u3 <> -9223372036854775808.0 AS cu, i4 <> -9223372036854775808.0 AS d, u4 <> -9223372036854775808.0 AS du, i8 <> -9223372036854775808.0 AS e, u8 <> -9223372036854775808.0 AS eu FROM t1;
prepare s2 from "SELECT i1 <> ? AS a, u1 <> ? AS au, i2 <> ? AS b, u2 <> ? AS bu, i3 <> ? AS c, u3 <> ? AS cu, i4 <> ? AS d, u4 <> ? AS du, i8 <> ? AS e, u8 <> ? AS eu FROM t1";
execute s2 using @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv;
SELECT i1 <> -9223372036854775808.0e0 AS a, u1 <> -9223372036854775808.0e0 AS au, i2 <> -9223372036854775808.0e0 AS b, u2 <> -9223372036854775808.0e0 AS bu, i3 <> -9223372036854775808.0e0 AS c, u3 <> -9223372036854775808.0e0 AS cu, i4 <> -9223372036854775808.0e0 AS d, u4 <> -9223372036854775808.0e0 AS du, i8 <> -9223372036854775808.0e0 AS e, u8 <> -9223372036854775808.0e0 AS eu FROM t1;
prepare s2 from "SELECT i1 <> ? AS a, u1 <> ? AS au, i2 <> ? AS b, u2 <> ? AS bu, i3 <> ? AS c, u3 <> ? AS cu, i4 <> ? AS d, u4 <> ? AS du, i8 <> ? AS e, u8 <> ? AS eu FROM t1";
execute s2 using @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv;
SELECT i1 <> '-9223372036854775808' AS a, u1 <> '-9223372036854775808' AS au, i2 <> '-9223372036854775808' AS b, u2 <> '-9223372036854775808' AS bu, i3 <> '-9223372036854775808' AS c, u3 <> '-9223372036854775808' AS cu, i4 <> '-9223372036854775808' AS d, u4 <> '-9223372036854775808' AS du, i8 <> '-9223372036854775808' AS e, u8 <> '-9223372036854775808' AS eu FROM t1;
prepare s2 from "SELECT i1 <> ? AS a, u1 <> ? AS au, i2 <> ? AS b, u2 <> ? AS bu, i3 <> ? AS c, u3 <> ? AS cu, i4 <> ? AS d, u4 <> ? AS du, i8 <> ? AS e, u8 <> ? AS eu FROM t1";
execute s2 using @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv;
SELECT i1 < -9223372036854775808 AS a, u1 < -9223372036854775808 AS au, i2 < -9223372036854775808 AS b, u2 < -9223372036854775808 AS bu, i3 < -9223372036854775808 AS c, u3 < -9223372036854775808 AS cu, i4 < -9223372036854775808 AS d, u4 < -9223372036854775808 AS du, i8 < -9223372036854775808 AS e, u8 < -9223372036854775808 AS eu FROM t1;
prepare s3 from "SELECT i1 < ? AS a, u1 < ? AS au, i2 < ? AS b, u2 < ? AS bu, i3 < ? AS c, u3 < ? AS cu, i4 < ? AS d, u4 < ? AS du, i8 < ? AS e, u8 < ? AS eu FROM t1";
execute s3 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 < -9223372036854775808.0 AS a, u1 < -9223372036854775808.0 AS au, i2 < -9223372036854775808.0 AS b, u2 < -9223372036854775808.0 AS bu, i3 < -9223372036854775808.0 AS c, u3 < -9223372036854775808.0 AS cu, i4 < -9223372036854775808.0 AS d, u4 < -9223372036854775808.0 AS du, i8 < -9223372036854775808.0 AS e, u8 < -9223372036854775808.0 AS eu FROM t1;
prepare s3 from "SELECT i1 < ? AS a, u1 < ? AS au, i2 < ? AS b, u2 < ? AS bu, i3 < ? AS c, u3 < ? AS cu, i4 < ? AS d, u4 < ? AS du, i8 < ? AS e, u8 < ? AS eu FROM t1";
execute s3 using @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv, @dv;
SELECT i1 < -9223372036854775808.0e0 AS a, u1 < -9223372036854775808.0e0 AS au, i2 < -9223372036854775808.0e0 AS b, u2 < -9223372036854775808.0e0 AS bu, i3 < -9223372036854775808.0e0 AS c, u3 < -9223372036854775808.0e0 AS cu, i4 < -9223372036854775808.0e0 AS d, u4 < -9223372036854775808.0e0 AS du, i8 < -9223372036854775808.0e0 AS e, u8 < -9223372036854775808.0e0 AS eu FROM t1;
prepare s3 from "SELECT i1 < ? AS a, u1 < ? AS au, i2 < ? AS b, u2 < ? AS bu, i3 < ? AS c, u3 < ? AS cu, i4 < ? AS d, u4 < ? AS du, i8 < ? AS e, u8 < ? AS eu FROM t1";
execute s3 using @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv, @fv;
SELECT i1 < '-9223372036854775808' AS a, u1 < '-9223372036854775808' AS au, i2 < '-9223372036854775808' AS b, u2 < '-9223372036854775808' AS bu, i3 < '-9223372036854775808' AS c, u3 < '-9223372036854775808' AS cu, i4 < '-9223372036854775808' AS d, u4 < '-9223372036854775808' AS du, i8 < '-9223372036854775808' AS e, u8 < '-9223372036854775808' AS eu FROM t1;
prepare s3 from "SELECT i1 < ? AS a, u1 < ? AS au, i2 < ? AS b, u2 < ? AS bu, i3 < ? AS c, u3 < ? AS cu, i4 < ? AS d, u4 < ? AS du, i8 < ? AS e, u8 < ? AS eu FROM t1";
execute s3 using @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv, @sv;
SELECT i1 >= -9223372036854775808 AS a, u1 >= -9223372036854775808 AS au, i2 >= -9223372036854775808 AS b, u2 >= -9223372036854775808 AS bu, i3 >= -9223372036854775808 AS c, u3 >= -9223372036854775808 AS cu, i4 >= -9223372036854775808 AS d, u4 >= -9223372036854775808 AS du, i8 >= -9223372036854775808 AS e, u8 >= -9223372036854775808 AS eu FROM t1;
prepare s4 from "SELECT i1 >= ? AS a, u1 >= ? AS au, i2 >= ? AS b, u2 >= ? AS bu, i3 >= ? AS c, u3 >= ? AS cu, i4 >= ? AS d, u4 >= ? AS du, i8 >= ? AS e, u8 >= ? AS eu FROM t1";
execute s4 using @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv, @iv;
SELECT i1 >= -9223372036854775808.0 AS a, u1 >= -9223372036854775808.0 AS au, i2 >= -9223372036854775808.0 AS b, u2 >= -9223372036854775808.0 AS bu, i3 >= -9223372036854775808.0 AS c, u3 >= -9223372036854775808.0 AS cu, i4 >= -9223372036854775808.0 AS d, u4 >= -9223372036854775808.0 AS du, i8 >= -9223372036854775808.0 AS e, u8 >= -9223372036854775808.0 AS eu FROM t1;
