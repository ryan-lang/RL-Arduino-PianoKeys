use strictures 2;
use IO::Async::Stream;
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use DDP;
use Fcntl qw( O_RDWR O_EXCL );
use Music::Chord::Note;
use MIDI::Simple;
use Try::Tiny;
use Music::Chord::Positions;
use List::Util qw/uniq/;
use JSON::XS;

my $config = Options->new_with_options;
my $Chord  = Music::Chord::Positions->new;
my $Note   = Music::Chord::Note->new();

my $KEY_MAP = {
    25  => 0,
    26=>2,
    27=>4,
    28=>6,
    29=>8,
    30=>10,
    31=>11,
    32=>13,
    33=>15,
    34=>17,
    35=>19,
    36=>21,
    37=>23,
    38=>25,
    39=>27,
    40=>29,
    41=>31,
    42=>33,
    43=>35,
    44=>37,
    45=>39,
    46=>41,
    47=>43,
    48=>45,
    49=>47,
    50=>49,
    51=>51,
    52=>53,
    53=>55,
    54=>57,
    55=>59,
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
    72=>92,
    73=>94,
    74=>96,
    75=>98,
    76=>100,
    77=>102,
    78=>104,
    79=>106,
    80=>108,
    81=>110,
    82=>112,
    83=>114,
    84=>116,
    85=>118,
    86=>120,
    87=>122,
    88=>124,
    89=>126,
    90=>128,
    91=>130,
    92=>132,
    93=>134,
    94=>136,
    95=>138,
    96=>140,
    97=>142,
    98=>143
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

            if($res){
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

        my @write_queue = (encode_json({cmd=>'allOff'}));
        try {
            if(!$req || $req eq ''){
                push @write_queue, map{ join(',', $_, 255,255,255,0) } sort {$a <=> $b} values %{$KEY_MAP};
            }else{
                $$buffref =~ s/$req//;

                my ( $tonic, $kind ) = ( $req =~ /([A-G][b#]?)(.+)?/ );

                my @scalic     = $Note->chord_num($kind);
                my $inversions = $Chord->chord_inv( \@scalic );
                unshift @{$inversions}, [@scalic];

                my $scale = $Note->scale($tonic);

                # my @note_nums = $score->Notes;
                # my @pixel_nums = map { ( $_ - $STARTING_NOTE ) * $PIXELS_PER_KEY } @note_nums;

                # map { $_ =~ s/#/sharp/g } @notes;
                # map { $_ =~ s/b/flat/g } @notes;

                # # my $score = MIDI::Simple->new_score();
                # # $score->Octave(2);
                # # $score->n(@notes);

                # my @note_nums = $score->Notes;
                # my $oct       = $score->Octave;

                # $music->process;
                # p $music;

                # # p $oct;
                # # p @note_nums;

                my @pixel_nums = ();
                foreach my $inversion ( @{$inversions} ) {
                    my @shifted = map{ $_ + 60 + $scale } @{$inversion};
                    p @shifted;
                    my @unmapped_keys = grep{ !(exists $KEY_MAP->{$_}) } @shifted;
                    p @unmapped_keys;

                    push @pixel_nums, map { $KEY_MAP->{$_} || 0 } @shifted;
                }

                push @write_queue, encode_json({pixels=>[uniq @pixel_nums], color=>[50,205,50]});
            }

            p @write_queue;
            map{ $stream->write( "$_\n" ); } @write_queue;
        }
        catch {
            warn $_;
        };

        return 0;

    }
);
$loop->add($input_stream);
$loop->run();

BEGIN {

    package Options;
    use Moo;
    use MooX::Options;

    option device => (
        is       => 'ro',
        format   => 's',
        required => 1
    );

    1;
}