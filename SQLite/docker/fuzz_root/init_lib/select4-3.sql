DROP TABLE IF EXISTS t1;
CREATE TABLE t1(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z, PRIMARY KEY(a,b DESC)) WITHOUT ROWID;

WITH RECURSIVE c(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM c WHERE x<100) INSERT INTO t1(a,b,c,d) SELECT x%10, x/10, x, printf('xyz%dabc',x) FROM c;

SELECT t3.c FROM (SELECT a,max(b) AS m FROM t1 WHERE a>=5 GROUP BY a) AS t2 JOIN t1 AS t3 WHERE t2.a=t3.a AND t2.m=t3.b ORDER BY t3.a;
SELECT t3.c FROM (SELECT a,max(b) AS m FROM t1 WHERE a>=5 GROUP BY a) AS t2 CROSS JOIN t1 AS t3 WHERE t2.a=t3.a AND t2.m=t3.b ORDER BY t3.a;
SELECT t3.c FROM (SELECT a,max(b) AS m FROM t1 WHERE a>=5 GROUP BY a) AS t2 LEFT JOIN t1 AS t3 WHERE t2.a=t3.a AND t2.m=t3.b ORDER BY t3.a;
