requires 'perl', '5.024001';

requires 'strictures';
requires 'IO::Async::Stream';
requires 'Music::Chord::Note';
requires 'Text::Chord::Piano';
requires 'MIDI::Simple';
requires 'MooX::Options';
 
on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Compile';
};

