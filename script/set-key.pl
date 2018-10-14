use strictures 2;
use IO::Async::Stream;
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use DDP;
use Fcntl qw( O_RDWR O_EXCL );
use MIDI::Simple;
use Try::Tiny;
use List::Util qw/uniq/;
use JSON::XS;
use Music::Chord::Note;
use Music::Chord::Positions;
use Music::AtonalUtil;
use Music::Scales;

my $BASE_COLOR = [ 50,  205, 50 ];
my $SUS_COLOR  = [ 255, 0,   0 ];

my $config = Options->new_with_options;
my $Chord  = Music::Chord::Positions->new;
my $Note   = Music::Chord::Note->new();
my $Util   = Music::AtonalUtil->new();

my $KEY_MAP = {
    25 => 0,
    26 => 2,
    27 => 4,
    28 => 6,
    29 => 8,
    30 => 10,
    31 => 11,
    32 => 13,
    33 => 15,
    34 => 17,
    35 => 19,
    36 => 21,
    37 => 23,
    38 => 25,
    39 => 27,
    40 => 29,
    41 => 31,
    42 => 33,
    43 => 35,
    44 => 37,
    45 => 39,
    46 => 41,
    47 => 43,
    48 => 45,
    49 => 47,
    50 => 49,
    51 => 51,
    52 => 53,
    53 => 55,
    54 => 57,
    55 => 59,
    56 => 61,
    57 => 63,
    58 => 65,
    59 => 67,
    60 => 69,
    61 => 71,
    62 => 72,
    63 => 74,
    64 => 76,
    65 => 78,
    66 => 80,
    67 => 82,
    68 => 84,
    69 => 86,
    70 => 88,
    71 => 90,
    72 => 92,
    73 => 94,
    74 => 96,
    75 => 98,
    76 => 100,
    77 => 102,
    78 => 104,
    79 => 106,
    80 => 108,
    81 => 110,
    82 => 112,
    83 => 114,
    84 => 116,
    85 => 118,
    86 => 120,
    87 => 122,
    88 => 124,
    89 => 126,
    90 => 128,
    91 => 130,
    92 => 132,
    93 => 134,
    94 => 136,
    95 => 138,
    96 => 140,
    97 => 142,
    98 => 143
};

my $LEDS           = 144;
my $KEYS           = 80;
my $PIXELS_PER_KEY = 144 / 80;
my $STARTING_NOTE  = 4;

my $loop = IO::Async::Loop->new;
my $fh;
my $path = $config->device;
sysopen( $fh, $path, O_RDWR | O_EXCL, 0755 ) or die qq{Can't open "$path": $!\n};

my $stream = IO::Async::Stream->new(
    read_handle  => $fh,
    write_handle => $fh,
    on_read      => sub {
        my ( $self, $buffref, $eof ) = @_;

        if ( length $$buffref ) {
            my ($res) = $$buffref =~ /(.+)(\n|\r)/;

            if ($res) {
                $$buffref =~ s/$res//g;

                #p $res;
            }
        }

        return 0;
    },
    on_write_error => sub {
        my ( $stream, $err ) = @_;
        warn $err;
    }
);

$loop->add($stream);

my $input_stream = IO::Async::Stream->new(
    read_handle => \*STDIN,
    on_read     => sub {
        my ( $self, $buffref, $eof ) = @_;
        my ($req) = $$buffref =~ /(.+)(\n|\r)/;

        my @write_queue = ( encode_json( { cmd => 'allOff' } ) );
        try {
            if ($req) {
                $$buffref =~ s/$req//;

                my ( $tonic, $kind ) = ( $req =~ /([A-G][b#]?)(.+)?/ );
                my $scale = $Note->scale($tonic);

                if ( $config->output eq 'chord' ) {

                    my @scalic = $Note->chord_num($kind);

                    #my $permute = $Chord->chord_pos( \@scalic, allow_transpositions => 1, );
                    #p $permute;

                    my $inversions = $Chord->chord_inv( \@scalic );
                    unshift @{$inversions}, [@scalic];

                    p $inversions;

                    my @pixel_nums = transpose_keys( $inversions, $scale );
                    push @write_queue,
                        encode_json( { pixels => \@pixel_nums, color => $BASE_COLOR } );
                }
                elsif ( $config->output eq 'note' ) {
                    my @pixel_nums = transpose_keys( [ [$scale] ], $scale );
                    p @pixel_nums;

                    push @write_queue,
                        encode_json( { pixels => \@pixel_nums, color => $BASE_COLOR } );
                }
                elsif ( $config->output eq 'scale' ) {
                    my @scale = get_scale_nums( $config->scale_mode );
                    p @scale;

                    my @pixel_nums = transpose_keys( [ \@scale ], $scale );
                    push @write_queue,
                        encode_json( { pixels => \@pixel_nums, color => $BASE_COLOR } );
                }
            }

            p @write_queue;
            map { $stream->write("$_\n"); } @write_queue;
        }
        catch {
            warn $_;
        };

        return 0;

    }
);
$loop->add($input_stream);
$loop->run();

sub transpose_keys {
    my ( $sets, $scale ) = @_;

    my @keys = ();
    foreach my $set ( @{$sets} ) {
        my $pos = 60;

        # from 60, down to 0
        while ( $pos > 0 ) {
            push @keys, map { $_ + $pos + $scale } @{$set};
            $pos -= 12;
        }

        $pos = 60;

        # from 60, up to max
        while ( $pos <= 98 ) {
            push @keys, map { $_ + $pos + $scale } @{$set};
            $pos += 12;
        }
    }

    p @keys;

    my @pixel_nums
        = uniq sort { $a <=> $b } grep {defined} map { $KEY_MAP->{$_} } uniq(@keys);

    return @pixel_nums;
}

BEGIN {

    package Options;
    use Moo;
    use MooX::Options;

    option device => (
        is       => 'ro',
        format   => 's',
        required => 1
    );

    option output => (
        is      => 'ro',
        format  => 's',
        default => 'chord'
    );

    option scale_mode => (
        is      => 'ro',
        format  => 's',
        default => 'ionian'
    );

    1;
}
