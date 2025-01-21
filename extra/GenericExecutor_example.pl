
use Finance::Quote;
use Data::Dumper;

$q = Finance::Quote->new(
        "GenericExecutor", 
        parameters => { EXECUTOR => 'python', 
                        FETCHER  => 'python_example.py'}
        );

my @ticker = @ARGV;

if (!@ticker) {
    @ticker = (
        "USDUSD=X",
        "^DJI",
    );
}

    %info = $q->fetch('run_executor', @ticker);
    print Dumper(%info);

1;