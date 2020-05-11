use Cro::HTTP::Session::Persistent;
use DB::Pg;
use JSON::Fast;

#| A Cro HTTP session storage using Postgres. Expects to be parmeterized
#| with the session type.
role Cro::HTTP::Session::Pg[::Session] does Cro::HTTP::Session::Persistent[Session] {
    #| The database connection.
    has DB::Pg $.db is required;

    #| The duration of the session; defaults to 60 minutes.
    has Duration $.duration = Duration.new(60 * 60);

    #| The sessions table name; defaults to 'sessions'.
    has Str $.sessions-table = 'sessions';

    #| The session ID column name; defaults to 'id'.
    has Str $.id-column = 'id';

    #| The session state column name; defaults to 'state'.
    has Str $.state-column = 'state';

    #| The session expiration column; defaults to 'expiration'.
    has Str $.expiration-column = 'expiration';

    #| Creates a new session by making a database table entry.
    method create(Str $session-id) {
        $!db.query(q:c:to/QUERY/, $session-id, "", DateTime.now + $!duration);
            INSERT INTO {$!sessions-table} ({$!id-column}, {$!state-column}, {$!expiration-column})
            VALUES ($1, $2, $3);
            QUERY
    }

    #| Loads a session from the database.
    method load(Str $session-id) {
        self.deserialize($!db.query(q:c:to/QUERY/, $session-id).value);
            SELECT {$!state-column}
            FROM {$!sessions-table}
            WHERE {$!id-column} = $1
            QUERY
    }

    #| Saves a session to the database.
    method save(Str $session-id, Session $session --> Nil) {
        my Str $json = self.serialize($session);
        $!db.query(q:c:to/QUERY/, $session-id, $json, DateTime.now + $!duration);
            UPDATE {$!sessions-table}
            SET {$!state-column} = $2,
                {$!expiration-column} = $3
            WHERE {$!id-column} = $1;
            QUERY
    }

    #| Clears expired sessions from the database.
    method clear(--> Nil) {
        $!db.query(q:c:to/QUERY/, DateTime.now);
        DELETE FROM {$!sessions-table}
        WHERE {$!expiration-column} < $1;
        QUERY
    }

    #| Serialize a session for storage. By default, serializes its
    #| public attributes into JSON (obtained by .Capture.hash); for
    #| any non-trivial session state, this shall need to be overridden.
    method serialize(Session $s) {
        to-json $s.Capture.hash
    }

    #| Deserialize a session from storage. By default, passes the
    #| serialized data to the new method of the session. For any
    #| non-trivial state, this will need to be overridden.
    method deserialize($d) {
        Session.new(|from-json($d))
    }
}
