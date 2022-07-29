CREATE EXTENSION test_shm_mq;
SELECT test_shm_mq(1024, '', 2000, 1);
SELECT test_shm_mq(1024, 'a', 2001, 1);
SELECT test_shm_mq(32768, (select string_agg(chr(32+(random()*95)::int), '') from generate_series(1,(100+900*random())::int)), 10000, 1);
SELECT test_shm_mq(100, (select string_agg(chr(32+(random()*95)::int), '') from generate_series(1,(100+200*random())::int)), 10000, 1);
SELECT test_shm_mq_pipelined(16384, (select string_agg(chr(32+(random()*95)::int), '') from generate_series(1,270000)), 200, 3);
