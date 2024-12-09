# metadata_handler.pl
#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use Crypt::CBC;
use Digest::SHA qw(sha256);

sub generate_key_iv {
    my ($password) = @_;
    my $key = sha256($password);
    my $iv = substr(sha256($key), 0, 16);  # 16-byte IV
    return ($key, $iv);
}

sub store_metadata {
    my ($file, $password) = @_;
    my ($key, $iv) = generate_key_iv($password);

    my %metadata = (original_name => $file);
    my $json = encode_json(\%metadata);

    my $cipher = Crypt::CBC->new(
        -key         => $key,
        -cipher      => 'Crypt::OpenSSL::AES',
        -iv          => $iv,
        -header      => 'none',
        -literal_key => 1,
    );

    open(my $fh, '>:raw', "$file.meta") or die "Cannot write metadata: $!";
    print $fh $cipher->encrypt($json);
    close($fh);
}

sub retrieve_metadata {
    my ($file, $password) = @_;
    my ($key, $iv) = generate_key_iv($password);

    open(my $fh, '<:raw', "$file.meta") or die "Cannot read metadata: $!";
    my $encrypted = do { local $/; <$fh> };
    close($fh);

    my $cipher = Crypt::CBC->new(
        -key         => $key,
        -cipher      => 'Crypt::OpenSSL::AES',
        -iv          => $iv,
        -header      => 'none',
        -literal_key => 1,
    );

    my $json;
    eval {
        $json = $cipher->decrypt($encrypted);
        my $metadata = decode_json($json);
        print $metadata->{original_name};
    };
    if ($@) {
        die "Incorrect password\n";
    }
}

# Main execution
my ($action, $file, $password) = @ARGV;
die "Usage: $0 [--store|--retrieve] file password\n" unless $action && $file && $password;

if ($action eq '--store') {
    store_metadata($file, $password);
} elsif ($action eq '--retrieve') {
    retrieve_metadata($file, $password);
} else {
    die "Invalid action. Use --store or --retrieve.\n";
}