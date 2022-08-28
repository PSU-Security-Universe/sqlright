CREATE TABLE A(Name text);
CREATE TABLE Items(ItemName text , Name text);
INSERT INTO Items VALUES('Item1','Parent');
INSERT INTO Items VALUES('Item2','Parent');
CREATE TABLE B(Name text);
SELECT Items.ItemName FROM Items LEFT JOIN A ON (A.Name = Items.ItemName and Items.ItemName = 'dummy') LEFT JOIN B ON (B.Name = Items.ItemName) WHERE Items.Name = 'Parent' ORDER BY Items.ItemName;
