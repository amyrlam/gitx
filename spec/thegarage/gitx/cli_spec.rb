require 'spec_helper'
require 'timecop'

describe Thegarage::Gitx::CLI do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::CLI.new(args, options, config) }

  before do
    # default current branch to: feature-branch
    allow(cli).to receive(:current_branch).and_return('feature-branch')
  end

  describe '#update' do
    let(:git) { double('fake git') }
    before do
      allow(cli).to receive(:git).and_return(git)
    end

    before do
      expect(git).to receive(:update)

      cli.update
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end

  describe '#integrate' do
    let(:git) { double('fake git') }
    before do
      allow(cli).to receive(:git).and_return(git)
    end
    context 'when target branch is ommitted' do
      before do
        expect(git).to receive(:update)

        expect(cli).to receive(:run).with("git branch -D staging", capture: true).ordered
        expect(cli).to receive(:run).with("git fetch origin", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout staging", capture: true).ordered
        expect(cli).to receive(:run).with("git pull . feature-branch", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin HEAD", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout feature-branch", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout feature-branch", capture: true).ordered

        cli.integrate
      end
      it 'defaults to staging branch' do
        should meet_expectations
      end
    end
    context 'when target branch == prototype' do
      before do
        expect(git).to receive(:update)

        expect(cli).to receive(:run).with("git branch -D prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git fetch origin", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git pull . feature-branch", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin HEAD", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout feature-branch", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout feature-branch", capture: true).ordered

        cli.integrate 'prototype'
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch != staging || prototype' do
      it 'raises an error' do
        expect(git).to receive(:update)

        lambda {
          cli.integrate 'some-other-branch'
        }.should raise_error(/Only aggregate branches are allowed for integration/)
      end
    end
  end

  describe '#release' do
    let(:git) { double('fake git') }
    before do
      allow(cli).to receive(:git).and_return(git)
    end
    context 'when user rejects release' do
      before do
        expect(cli).to receive(:yes?).and_return(false)

        expect(git).to receive(:update)

        cli.release
      end
      it 'only runs update commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release' do
      before do
        expect(cli).to receive(:yes?).and_return(true)
        expect(cli).to receive(:branches).and_return(%w( old-merged-feature )).twice

        expect(git).to receive(:update)

        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered
        expect(cli).to receive(:run).with("git pull origin master", capture: true).ordered
        expect(cli).to receive(:run).with("git pull . feature-branch", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin HEAD", capture: true).ordered
        expect(cli).to receive(:run).with("git branch -D staging", capture: true).ordered
        expect(cli).to receive(:run).with("git fetch origin", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout staging", capture: true).ordered
        expect(cli).to receive(:run).with("git pull . master", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin HEAD", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered
        expect(cli).to receive(:run).with("git pull", capture: true).ordered
        expect(cli).to receive(:run).with("git remote prune origin", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin --delete old-merged-feature", capture: true).ordered
        expect(cli).to receive(:run).with("git branch -d old-merged-feature", capture: true).ordered

        cli.release
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
  end

  describe '#nuke' do
    context 'when target branch == prototype and --destination == master' do
      let(:options) do
        {
          destination: 'master'
        }
      end
      let(:buildtags) do
        %w( build-master-2013-10-01-01 ).join("\n")
      end
      before do
        expect(cli).to receive(:yes?).and_return(true)

        expect(cli).to receive(:run).with("git fetch --tags", capture: true).ordered
        expect(cli).to receive(:run).with("git tag -l 'build-master-*'", capture: true).and_return(buildtags).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered
        expect(cli).to receive(:run).with("git branch -D prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin --delete prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout -b prototype build-master-2013-10-01-01", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git branch --set-upstream-to origin/prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered

        cli.nuke 'prototype'
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch == staging and --destination == staging' do
      let(:options) do
        {
          destination: 'staging'
        }
      end
      let(:buildtags) do
        %w( build-staging-2013-10-02-02 ).join("\n")
      end
      before do
        expect(cli).to receive(:yes?).and_return(true)

        expect(cli).to receive(:run).with("git fetch --tags", capture: true).ordered
        expect(cli).to receive(:run).with("git tag -l 'build-staging-*'", capture: true).and_return(buildtags).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered
        expect(cli).to receive(:run).with("git branch -D staging", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin --delete staging", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout -b staging build-staging-2013-10-02-02", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin staging", capture: true).ordered
        expect(cli).to receive(:run).with("git branch --set-upstream-to origin/staging", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered

        cli.nuke 'staging'
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch == prototype and destination prompt == nil' do
      let(:buildtags) do
        %w( build-prototype-2013-10-03-03 ).join("\n")
      end
      before do
        expect(cli).to receive(:ask).and_return('')
        expect(cli).to receive(:yes?).and_return(true)

        expect(cli).to receive(:run).with("git fetch --tags", capture: true).ordered
        expect(cli).to receive(:run).with("git tag -l 'build-prototype-*'", capture: true).and_return(buildtags).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered
        expect(cli).to receive(:run).with("git branch -D prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin --delete prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout -b prototype build-prototype-2013-10-03-03", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git branch --set-upstream-to origin/prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered

        cli.nuke 'prototype'
      end
      it 'defaults to prototype and should run expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch == prototype and destination prompt = master' do
      let(:buildtags) do
        %w( build-master-2013-10-01-01 ).join("\n")
      end
      before do
        expect(cli).to receive(:ask).and_return('master')
        expect(cli).to receive(:yes?).and_return(true)

        expect(cli).to receive(:run).with("git fetch --tags", capture: true).ordered
        expect(cli).to receive(:run).with("git tag -l 'build-master-*'", capture: true).and_return(buildtags).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered
        expect(cli).to receive(:run).with("git branch -D prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin --delete prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout -b prototype build-master-2013-10-01-01", capture: true).ordered
        expect(cli).to receive(:run).with("git push origin prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git branch --set-upstream-to origin/prototype", capture: true).ordered
        expect(cli).to receive(:run).with("git checkout master", capture: true).ordered

        cli.nuke 'prototype'
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch != staging || prototype' do
      it 'raises error' do
        lambda {
          expect(cli).to receive(:ask).and_return('master')
          expect(cli).to receive(:yes?).and_return(true)
          cli.nuke 'not-an-integration-branch'
        }.should raise_error(/Only aggregate branches are allowed to be reset/)
      end
    end
    context 'when user does not confirm nuking the target branch' do
      let(:buildtags) do
        %w( build-master-2013-10-01-01 ).join("\n")
      end
      before do
        expect(cli).to receive(:ask).and_return('master')
        expect(cli).to receive(:yes?).and_return(false)

        expect(cli).to receive(:run).with("git fetch --tags", capture: true).ordered
        expect(cli).to receive(:run).with("git tag -l 'build-master-*'", capture: true).and_return(buildtags).ordered

        cli.nuke 'prototype'
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when no known good build tag found' do
      let(:buildtags) do
        ''
      end
      it 'raises error' do
        expect(cli).to receive(:ask).and_return('master')

        expect(cli).to receive(:run).with("git fetch --tags", capture: true).ordered
        expect(cli).to receive(:run).with("git tag -l 'build-master-*'", capture: true).and_return(buildtags).ordered

        expect { cli.nuke('prototype') }.to raise_error(/No known good tag found for branch/)
      end
    end
  end

  describe '#reviewrequest' do
    let(:github) { double('fake github') }
    let(:git) { double('fake git') }
    let(:pull_request) do
      {
        'html_url' => 'https://path/to/new/pull/request',
        'head' => {
          'ref' => 'branch_name'
        }
      }
    end
    before do
      allow(cli).to receive(:github).and_return(github)
      allow(cli).to receive(:git).and_return(git)
    end
    context 'when pull request does not exist' do
      let(:authorization_token) { '123123' }
      let(:changelog) { '* made some fixes' }
      before do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect(github).to receive(:find_pull_request).and_return(nil)
        expect(github).to receive(:create_pull_request).and_return(pull_request)

        expect(git).to receive(:update)
        expect(cli).to receive(:run).with("git log master...feature-branch --no-merges --pretty=format:'* %s%n%b'", capture: true).and_return("2013-01-01 did some stuff").ordered
        cli.reviewrequest
      end
      it 'creates github pull request' do
        should meet_expectations
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when authorization_token is missing' do
      let(:authorization_token) { nil }
      it do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect { cli.reviewrequest }.to raise_error(/token not found/)
      end
    end
    context 'when pull request already exists' do
      let(:authorization_token) { '123123' }
      before do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect(github).to receive(:find_pull_request).and_return(pull_request)
        expect(github).to_not receive(:create_pull_request)

        cli.reviewrequest
      end
      it 'does not create new pull request' do
        should meet_expectations
      end
    end
    context 'when --assignee option passed' do
      let(:options) do
        {
          assignee: 'johndoe'
        }
      end
      let(:authorization_token) { '123123' }
      before do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect(github).to receive(:find_pull_request).and_return(pull_request)
        expect(github).to receive(:assign_pull_request)

        cli.reviewrequest
      end
      it 'calls assign_pull_request method' do
        should meet_expectations
      end
    end
    context 'when --open flag passed' do
      let(:options) do
        {
          open: true
        }
      end
      let(:authorization_token) { '123123' }
      before do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect(github).to receive(:find_pull_request).and_return(pull_request)

        expect(cli).to receive(:run).with("open #{pull_request['html_url']}", capture: true).ordered
        cli.reviewrequest
      end
      it 'runs open command with pull request url' do
        should meet_expectations
      end
    end
  end

  describe '#track' do
    let(:git) { double('fake git') }
    before do
      allow(cli).to receive(:git).and_return(git)
    end
    it 'calls git.track' do
      expect(git).to receive(:track)
      cli.track
    end
  end

  describe '#share' do
    let(:git) { double('fake git') }
    before do
      allow(cli).to receive(:git).and_return(git)
    end
    it 'calls git.share' do
      expect(git).to receive(:share)
      cli.share
    end
  end

  describe '#start' do
    let(:git) { double('fake git') }
    context 'when user inputs branch that is valid' do
      before do
        allow(cli).to receive(:git).and_return(git)
      end
      it 'calls git.start' do
        expect(git).to receive(:valid_new_branch_name?).with('new-branch').and_return(true)
        expect(git).to receive(:start).with('new-branch')

        cli.start 'new-branch'
      end
    end
  end

  describe '#buildtag' do
    let(:env_travis_branch) { nil }
    let(:env_travis_pull_request) { nil }
    let(:env_travis_build_number) { nil }
    before do
      ENV['TRAVIS_BRANCH'] = env_travis_branch
      ENV['TRAVIS_PULL_REQUEST'] = env_travis_pull_request
      ENV['TRAVIS_BUILD_NUMBER'] = env_travis_build_number
    end
    context 'when ENV[\'TRAVIS_BRANCH\'] is nil' do
      it 'raises Unknown Branch error' do
        expect { cli.buildtag }.to raise_error "Unknown branch. ENV['TRAVIS_BRANCH'] is required."
      end
    end
    context 'when the travis branch is master and the travis pull request is not false' do
      let(:env_travis_branch) { 'master' }
      let(:env_travis_pull_request) { '45' }
      before do
        expect(cli).to receive(:say).with("Skipping creation of tag for pull request: #{ENV['TRAVIS_PULL_REQUEST']}")
        cli.buildtag
      end
      it 'tells us that it is skipping the creation of the tag' do
        should meet_expectations
      end
    end
    context 'when the travis branch is NOT master and is not a pull request' do
      let(:env_travis_branch) { 'random-branch' }
      let(:env_travis_pull_request) { 'false' }
      before do
        expect(cli).to receive(:say).with(/Cannot create build tag for branch: #{ENV['TRAVIS_BRANCH']}/)
        cli.buildtag
      end
      it 'tells us that the branch is not supported' do
        should meet_expectations
      end
    end
    context 'when the travis branch is master and not a pull request' do
      let(:env_travis_branch) { 'master' }
      let(:env_travis_pull_request) { 'false' }
      let(:env_travis_build_number) { '24' }
      before do
        Timecop.freeze(Time.utc(2013, 10, 30, 10, 21, 28)) do
          expect(cli).to receive(:run).with("git tag build-master-2013-10-30-10-21-28 -a -m 'Generated tag from TravisCI build 24'", capture: true).ordered
          expect(cli).to receive(:run).with("git push origin build-master-2013-10-30-10-21-28", capture: true).ordered
          cli.buildtag
        end
      end
      it 'creates a tag for the branch and push it to github' do
        should meet_expectations
      end
    end
  end
end
