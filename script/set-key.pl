use strictures 2;
use IO::Async::Stream;
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use DDP;
use Fcntl qw( O_RDWR O_EXCL );
use Music::Chord::Note;
use MIDI::Simple;
use Try::Tiny;

my $config = Options->new_with_options;
my $music  = Music::Chord::Note->new();

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
            my @notes = $music->chord($req);
            map { $_ =~ s/#/sharp/g } @notes;
            map { $_ =~ s/b/flat/g } @notes;

            my $score = MIDI::Simple->new_score();
            $score->n(@notes);

            my @note_nums = $score->Notes;
            my @pixel_nums = map { ( $_ - $STARTING_NOTE ) * $PIXELS_PER_KEY } @note_nums;

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
