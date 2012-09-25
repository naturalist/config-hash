
use inc::Module::Install;

name 'Config-Hash';
license 'perl';
abstract 'Handle config files containing Perl hashes';
author 'minimalist - minimal@cpan.org';
version_from 'lib/Config/Hash.pm';

perl_version '5.006';
test_requires 'Test::More';
test_requires 'FindBin';

requires 'Carp';
requires 'File::Basename';
requires 'Hash::Merge';

WriteAll;
