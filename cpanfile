requires 'perl', '5.024001';

requires 'strictures';
requires 'IO::Async::Stream';
requires 'Music::Chord::Note';
requires 'Text::Chord::Piano';
requires 'MIDI::Simple';
requires 'MooX::Options';
requires 'Music::Intervals';
requires 'Music::Chord::Positions';
requires 'Music::AtonalUtil';
requires 'JSON::XS';
requires 'Music::Scales';
 
on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Compile';
};

