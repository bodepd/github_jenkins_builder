require 'github_api'


module PullRequestTester

  # figure out if a certain pull request can be tested.
  # Pull requests can only be tested if they have a comment
  # that contains the speficied expected_body in a PR comment
  # created by one of the approved admin.
  #
  # Parameters:
  #   pr::
  #     pull request object to be verified.
  #   admin_users::
  #     array of users who can approve pull requests for testing
  #   expected_body::
  #     expected body of a message that means a PR can be tested.
  def testable_pull_request?(
    pr,
    admin_users,
    expected_body = 'test_it',
    options       = {}
  )
    if ! pr['merged']
      if pr['mergeable']
        if pr['comments'] > 0
          comments = ::Github.new(options).issues.comments.all(
            pr['base']['user']['login'],
            pr['base']['repo']['name'],
            pr['number']
          )
          #puts 'going through comments'
          comments.each do |comment|
            if admin_users.include?(comment['user']['login'])
              if comment['body'] == expected_body
                return true
              end
            end
          end
        else
          #puts "PR: #{pr['number']} from #{pr['base']['repo']['name']} has no issue commments.\
          #I will not test it. We only test things approved."
        end
      else
        #puts "PR: #{pr['number']} from #{pr['base']['repo']['name']} cannot be merged, will not test"
      end
    else
      #puts "PR: #{pr['number']} from #{pr['base']['repo']['name']} was already merged, will not test"
    end
    #puts "Did not find comment matching #{expected_body}"
    return false
  end

  # publish a string as a gist.
  # publish a link to that gist as a issue comment.
  def publish_results(
    project_name,
    number,
    outcome,
    body,
    options,
    account     = 'puppetlabs',
    repo_prefix = 'puppetlabs-'
  )
    require 'github_api'
    github = ::Github.new(options)
    gist_response = github.gists.create(
      'description' => "#{project_name}/#{number}@#{Time.now.strftime("%Y%m%dT%H%M%S%z")}",
      'public'      => true,
      'files' => {
        'file1' => {'content' => body}
      }
    )
    comments = github.issues.comments.create(
      account,
      "#{repo_prefix}#{project_name}",
      number,
      'body' => "Test #{outcome}. Results can be found here: #{gist_response.html_url}"
    )
  end

  # scans a list of github repos, looking for open, mergable pull requests where one of the
  # 'admin' users has added a comment that contains the 'test_message'.
  def testable_pull_requests(
    project_names,
    admin_users,
    github_login,
    github_password,
    test_message = 'schedule_for_testing',
    account      = 'puppetlabs',
    repo_prefix  = 'puppetlabs-'
  )
    testable_pull_requests = {}
    project_names.each do |repo_name|
      options = { :login => github_login, :password => github_password }
      prs = ::Github.new(options).pull_requests.list(account, "#{repo_prefix}#{repo_name}")
      prs.each do |pr|
        # the data structure of pr returned from list (above) appears to be in a different format
        # than this get call, therefor, I need to get the number, and make this extra call.
        # this seems to justify my experience so far that this github_api plugin may not be worth using.
        number = pr['number']
        pr = ::Github.new(options).pull_requests.get(account, "#{repo_prefix}#{repo_name}", number)
        # I know this is lazy to do b/c it means every pull request will be validated twice based
        # on the current workflow with jenkins (where this will populate parameterized builds
        # that also check if the pull request is valid
        if testable_pull_request?(pr, admin_users + Array(github_login), test_message, options)
          if testable_pull_requests[repo_name]
            testable_pull_requests[repo_name].push(number)
          else
            testable_pull_requests[repo_name] = [number]
          end
        end
      end
    end
    testable_pull_requests
  end
end
