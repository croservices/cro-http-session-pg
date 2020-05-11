use Cro::HTTP::Auth;
use Cro::HTTP::Session::Pg;
use Cro::HTTP::Test;
use DB::Pg;
use Test;
use Test::Mock;

class MySession does Cro::HTTP::Auth {
    has $.user-id;
    method set-logged-in-user($!user-id --> Nil) {}
    method is-logged-in(--> Bool) {
        $!user-id.defined
    }
}

my $current-fake-json = '{ "user-id": null }';
my $fake-db = mocked(DB::Pg, returning => {
    query => class {
        method value() {
            $current-fake-json
        }
    }
});
sub routes() {
    use Cro::HTTP::Router;
    route {
        before Cro::HTTP::Session::Pg[MySession.new].new:
                db => $fake-db,
                cookie-name => 'myapp';

        get -> MySession $s, 'login' {
            $s.set-logged-in-user(42);
        }

        get -> MySession $s, 'logged-in' {
            content 'text/plain', $s.is-logged-in.Str;
        }
    }
}

test-service routes(), :http<1.1>, :cookie-jar, {
    test get('/logged-in'),
            status => 200,
            content-type => 'text/plain',
            body => 'False';

    check-mock $fake-db,
            *.called('query', times => 1, with => :($ where /INSERT/, *@)),
            *.called('query', times => 1, with => :($ where /UPDATE/, *@));

    test get('/login'),
            status => 204;

    check-mock $fake-db,
            *.called('query', times => 1, with => :($ where /INSERT/, *@)),
            *.called('query', times => 1, with => :($ where /SELECT/, *@)),
            *.called('query', times => 2, with => :($ where /UPDATE/, *@));

    $current-fake-json = '{ "user-id": 42 }';
    test get('/logged-in'),
            status => 200,
            content-type => 'text/plain',
            body => 'True';

    check-mock $fake-db,
            *.called('query', times => 1, with => :($ where /INSERT/, *@)),
            *.called('query', times => 2, with => :($ where /SELECT/, *@)),
            *.called('query', times => 3, with => :($ where /UPDATE/, *@));
}

done-testing;
