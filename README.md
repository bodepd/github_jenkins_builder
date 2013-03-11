This project does the following:

  monitor a set of github repos
  watch for pull requests where an admin has made the comment 'schedule_for_testing'
  submit these pull requests into jenkins jobs
  monitor those jenkins jobs
  publish the results of the tests as a gist that is linked to by the PR in a comment


this project is meant to be general purpose, but it was written specifically to run CI tests for modules,
so it still contains some hard-coded information.

this project uses torquebox to supply the MQ, caching, and background tasks.

it has the following torquebox components:

- GithubScanner - background task that monitors jenkins, looking for pull requests to test
- JenkinsBuildProcessor - pull requests to test are published to a queue, that triggers this actor
that processes those events by triggering jenkins jobs
- JenkinsBuildWatcher - monitors jenkins jobs, publishing the results to a gist linked to by the pull request when completed

The current state of the builds is kept on 3 cahces:

- build_cache - maintains a list of all jobs currently building
- success_cache - maintains a list of all jobs that succeeded
- fail_cahce - maintains a list of all jobs that failed

It also contains a sintra endpoint, /build_cache that can be used to monitor the state of these caches

TODO

- the caches should be persistent
- needs spec tests
- need to publish back some of the work to the jenkins_client_api library
- need to have better facilitaties for triggering tests to rebuild
