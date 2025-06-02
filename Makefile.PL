use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Finance::Quote::CMBChina',
    VERSION_FROM      => 'lib/Finance/Quote/CMBChina.pm',
    PREREQ_PM         => {
        'HTTP::Request'       => 0,
        'LWP::UserAgent'      => 0,
        'HTML::TreeBuilder::XPath' => 0,
        'Date::Parse'         => 0,
    },
    LICENSE           => 'perl',
    dist              => { COMPRESS => 'gzip -9n', SUFFIX => 'gz', },
    clean             => { FILES => 'Finance-Quote-CMBChina-*' },
);