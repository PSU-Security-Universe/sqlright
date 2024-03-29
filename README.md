# SQLRight: A General Platform to Test DBMS Logical Bugs

<a href="https://huhong789.github.io/papers/liang:sqlright.pdf"><img src="doc/paper.jpg" align="right" width="250"></a>

## Overview

`SQLRight` combines the coverage-based guidance, validity-oriented mutations and oracles to detect logical bugs for DBMS systems. `SQLRight` first mutates existing queries cooperatively. It inserts a set of oracle-required statements, and applies our validity-oriented mutations to improve the validity rate. Then, it sends the query to the oracle to create functionally equivalent query counterparts. `SQLRight` feeds all generated queries to the DBMS, and collects the execution results and the coverage information. After that, `SQLRight` invokes the oracle to compare the results of different queries to identify logical bugs. At last, it inserts the coverage-improving queries into the queue for future mutations.

For more details of `SQLRight`, plese check our [paper published on Usenix Security 2022](https://huhong789.github.io/papers/liang:sqlright.pdf).

Currently supported DBMS:
1. SQLite3
2. PostgreSQL
3. MySQL

The overview of `SQLRight` is illustrated by the diagram below.

<p align="center">
<img src="doc/sqlright-overview.jpg" width="90%" alt="The overview of SQLRight" border="1">
</p>

## Use SQLRight

- [Environment Setup](PREREQUISITE.md)
- [Get Docker Images](INSTALL.md)
- [Run Fuzzing](RUN.md)

## Add New Oracles

- [Develop New Oracles](DEVELOPMENT.md)

## Authors

- Yu Liang yuliang@psu.edu
- Song Liu songliu@psu.edu
- Hong Hu honghu@psu.edu

## Publications

```bib
Detecting Logical Bugs of DBMS with Coverage-based Guidance

@inproceedings{liang:sqlright,
  title        = {{Detecting Logical Bugs of DBMS with Coverage-based Guidance}},
  author       = {Yu Liang and Song Liu and Hong Hu},
  booktitle    = {Proceedings of the 31st USENIX Security Symposium (USENIX 2022)},
  month        = {aug},
  year         = {2022},
  address      = {Boston, MA},
}
```

