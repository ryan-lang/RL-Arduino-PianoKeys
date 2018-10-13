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

my $config = Options->new_with_options;
my $Chord  = Music::Chord::Positions->new;
my $Note   = Music::Chord::Note->new();

my $KEY_MAP = {
    4  => 0,
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
    71 => 90
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
            substr( $$buffref, 0, 3 ) = "";
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
        $$buffref =~ s/$req//;

        try {
            my ( $tonic, $kind ) = ( $req =~ /([A-G][b#]?)(.+)?/ );

            my @scalic     = $Note->chord_num($kind);
            my $inversions = $Chord->chord_inv( \@scalic );
            unshift @{$inversions}, [@scalic];

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

            my @pixel_nums;
            foreach my $inversion ( @{$inversions} ) {
                push @pixel_nums, map { $KEY_MAP->{$_} ? $KEY_MAP->{$_} + 60 : 0 } @{$inversion};
            }

            $stream->write( join( ',', @pixel_nums ) . "\n" );
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
