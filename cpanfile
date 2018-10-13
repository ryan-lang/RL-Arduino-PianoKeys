requires 'perl', '5.024001';

requires 'strictures';
 
on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Compile';
};

