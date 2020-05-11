# Cro::HTTP::Session::Pg

An implementation of Cro persistent sessions using Postgres.

## Assumptions

There are dozens of ways we might do session storage; this module handles
the case where: 

* The database is being accessed using `DB::Pg`.
* You're fine with the session state being serialized and stored as a
  string/blob in the database.

If these don't meet your needs, it's best to steal the code from this
module into your own application and edit it as needed.

## Database setup

Create a table like this in the database:

```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    state TEXT,
    expiration TIMESTAMP
);
```

You can change the table and column names, but will then have to specify
them when constructing the session state object.

## Minimal Cro application setup

First, create a session object if you do not already have one. This is
a class that holds the session state. We'll be saving/loading its content.
For example:

```raku
class MySession {
    has $.user-id;

    method set-logged-in-user($!user-id --> Nil) { }

    method is-logged-in(--> Bool) { $!user-id.defined }
}
```

In the case that:

* You are using the default table/column names
* Your session object can be serialized by serializing its public attributes
  to JSON, and deserialized by passing those back to new
* You are fine with the default 60 minute session expiration time

Then the only thing needed is to construct the session storage middleware with
a database handle and a session cookie name.

```raku
my $session-middleware = Cro::HTTP::Session::Pg[MySession].new:
    :$db,
    :cookie-name('my_app_name_session');
```

It can then be applied as application or `route`-block level middleware. 

## Tweaking the session duration

Pass a `Duration` object as the `duration` named argument:

```raku
my $session-middleware = Cro::HTTP::Session::Pg[MySession].new:
    :$db,
    :cookie-name('my_app_name_session'),
    :duration(Duration.new(15 #`(minutes) * 60)); 
```

## Tweaking the table and column names

Pass these named arguments as needed during construction:

* `sessions-table`
* `id-column`
* `state-column`
* `expiration-column`

## Controlling serialization

Instead of using the `Cro::HTTP::Session::Pg` role directly, create a
class that composes it.

```raku
class MySessionStore does Cro::HTTP::Session::Pg[MySession] {
    method serialize(MySession $s) {
        # Replace this with your serialization logic.
        to-json $s.Capture.hash
    }
    
    method deserialize($d --> MySession) {
        # Replace this with your deserialization logic.
        Session.new(|from-json($d))
    }
}
```
