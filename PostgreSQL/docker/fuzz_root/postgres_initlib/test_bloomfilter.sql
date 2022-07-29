CREATE EXTENSION test_bloomfilter;
SELECT test_bloomfilter(power => 23,    nelements => 838861,    seed => -1,    tests => 1);
