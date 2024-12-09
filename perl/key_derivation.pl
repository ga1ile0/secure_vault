# key_derivation.pl
#!/usr/bin/perl
use strict;
use warnings;
use Digest::SHA qw(sha256);

my $password = $ARGV[0] or die "No password provided\n";
print sha256($password);