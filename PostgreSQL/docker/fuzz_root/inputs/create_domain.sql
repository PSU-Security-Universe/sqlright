CREATE DOMAIN domainvarchar VARCHAR(5);
CREATE DOMAIN japanese_postal_code AS TEXTCHECK(   VALUE ~ '^\d{3} 'OR VALUE ~ '^\d{3}-\d{4} ');
