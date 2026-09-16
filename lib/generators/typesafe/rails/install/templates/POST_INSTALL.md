Typesafe::Rails is installed.

Next steps:

  1. Run `bin/rails db:migrate`.

  2. Add your API key: `bin/rails credentials:edit` and add:

       typesafe:
         api_key: sk-...

  3. Call System One through `Typesafe::Rails.client.ask`.

  4. Before calling `result.act!`, create an active policy for that answer
     key, or a wildcard `answer_key: "*"` policy for the decision type.
     `act!` intentionally fails closed when no policy exists.

Noul answers do not have TypeSafe confidence. Read `answer.noul` and apply
the probability threshold appropriate to your application instead of using
`act!`.
