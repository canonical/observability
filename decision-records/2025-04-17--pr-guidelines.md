**Authors:** @ca-scribner

## Decision

As discussed in [a previous cafe](https://github.com/canonical/observability-team/issues/18), we agree to strive for the following guidelines around PRs and PR reviews **when it is pragmatic to do so**.  These are guidelines, not hard rules, so exceptions are fine.  In general, we should police ourselves and work toward better over time.

Pull Requests:
* General rule: make pull requests as easy to review as possible, and "be kind to your future self" by making the objectives clear
* Include a meaningful description, including:
  * Why the change is happening (this could be a link to a parent issue)
  * What should happen (outcomes of the change, so people know what to look for)
* A few small PRs are better than a single big PR:
  * small PRs make it easier for people to review quickly and with better detail
  * ex: if you're implementing a feature and, to do it, you need to refactor some other code, split that refactor into a separate PR.  That way reviewers can first review the refactor (and clearly see nothing about the charm changed), then later focus specifically on the new feature

PR Reviews:
* When commenting, clearly state your desired outcome
  * State whether its a blocking comment or just a suggestion that they can ignore (ex: "Just a suggestion: I'd prefer that we captured these three tests as a single parametrized test.  If you disagree, you can ignore and resolve this"
  * State what you want the other person to do (avoid "I think this is broken" if possible, instead saying "I think this wont handle the `relation-changed` event properly, but you can do ```codeblock``` instead")
  * Use suggestions where possible, especially for minor changes like variable renames or comments
  * When something is unclear, make an attempt at clarifying (don't say "this is unclear", but instead maybe "I wasn't sure if this should return X or Y, should the comment here be '..."?")
  * If you find yourself writing "this is a nit"; consider omitting the comment altogether.
