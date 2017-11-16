require 'librarian'
require 'librarian/helpers'
require 'librarian/error'
require 'librarian/action/resolve'
require 'librarian/action/install'
require 'librarian/action/update'
require 'librarian/ansible'

require 'support/project_path'

module Librarian
  module Ansible
    module Source
      describe Git do
        let(:project_path) { ::Support::ProjectPath.project_path }
        let(:tmp_path) do
          project_path.join('tmp/spec/integration/ansible/source/git')
        end
        # after do
        #   tmp_path.rmtree if tmp_path && tmp_path.exist?
        # end

        let(:roles_path) do
          tmp_path.join('librarian_roles')
        end

        # depends on repo_path being defined in each context
        let(:env) { Environment.new(project_path: repo_path) }
        context 'Transitive dependencies should be resolved' do
          let(:sample_path) { tmp_path.join('level_zero') }
          let(:sample_metadata_zero) do
            { version: '1.0.0' }
          end
          let(:sample_path_one) { tmp_path.join('level_one') }
          let(:sample_metadata_one) do
            { version: '2.0.0' }
          end
          let(:sample_path_two) { tmp_path.join('level_two') }
          let(:sample_metadata_two) do
            { version: '3.0.0' }
          end
          before do
            sample_path.rmtree if sample_path.exist?
            sample_path.join('meta').mkpath
            sample_path.join('meta/main.yml').open('wb') do |f|
              f.write(YAML.dump(sample_metadata_zero))
            end
            Dir.chdir(sample_path) do
              `git init`
              `git config user.name "Simba"`
              `git config user.email "simba@savannah-pride.gov"`
              `git add meta/main.yml`
              `git commit -m "Initial commit."`
            end

            roles_path.rmtree if roles_path.exist?
            roles_path.mkpath
            sample_path_one.join('meta').mkpath
            sample_path_one.join('meta/main.yml').open('wb') do |f|
              f.write(YAML.dump(sample_metadata_one))
            end
            ansiblefile = Helpers.strip_heredoc(<<-ANSIBLEFILE)
              #!/usr/bin/env ruby
              role "level_zero", :git => #{sample_path.to_s.inspect}
            ANSIBLEFILE
            sample_path_one.join('Ansiblefile').open('wb') do |f|
              f.write(ansiblefile)
            end

            sample_path_two.join('meta').mkpath
            sample_path_two.join('meta/main.yml').open('wb') do |f|
              f.write(YAML.dump(sample_metadata_two))
            end
            ansiblefile = Helpers.strip_heredoc(<<-ANSIBLEFILE)
              #!/usr/bin/env ruby
              role "level_one", :git => #{sample_path_one.to_s.inspect}
            ANSIBLEFILE
            sample_path_two.join('Ansiblefile').open('wb') do |f|
              f.write(ansiblefile)
            end
            Dir.chdir(roles_path) do
              `git init`
              `git config user.name "Simba"`
              `git config user.email "simba@savannah-pride.gov"`
              `git add .`
              `git commit -m "Initial commit."`
            end
          end
          context 'resolving' do
            let(:repo_path) { tmp_path.join('repo/resolve') }
            before do
              repo_path.rmtree if repo_path.exist?
              repo_path.mkpath
              repo_path.join('librarian_roles').mkpath
              ansiblefile = Helpers.strip_heredoc(<<-ANSIBLEFILE)
                #!/usr/bin/env ruby
                role "level_zero", :git => #{sample_path.to_s.inspect}
              ANSIBLEFILE
              repo_path.join('Ansiblefile').open('wb') do |f|
                f.write(ansiblefile)
              end
            end
            context 'the resolve' do
              it 'should not raise an exception' do
                expect do
                  Librarian::Action::Resolve.new(env).run
                end.to_not raise_error
              end
            end
          end
          context 'installing' do
            let(:repo_path) { tmp_path.join('repo/install') }
            before do
              repo_path.rmtree if repo_path.exist?
              repo_path.mkpath
              repo_path.join(roles_path).mkpath
              ansiblefile = Helpers.strip_heredoc(<<-ANSIBLEFILE)
                #!/usr/bin/env ruby
                role "level_zero", :git => #{sample_path.to_s.inspect}
              ANSIBLEFILE
              repo_path.join('Ansiblefile').open('wb') { |f| f.write(ansiblefile) }

              Librarian::Action::Resolve.new(env).run
            end

            context 'the install' do
              it 'should not raise an exception' do
                expect { Action::Install.new(env).run }.to_not raise_error
              end
            end
            context 'the results' do
              before { Action::Install.new(env).run }

              it 'should create the lockfile' do
                repo_path.join('Ansiblefile.lock').should exist
              end
              context 'level_zero' do
                it 'should create the directory for the role ' do
                  repo_path.join('librarian_roles/level_zero').should exist
                end

                it 'should copy the role files into the role directory' do
                  repo_path.join('librarian_roles/level_zero/meta/main.yml').should exist
                end
              end
              context 'level_one' do
                it 'should create the directory for the role ' do
                  repo_path.join('librarian_roles/level_one').should exist
                end

                it 'should copy the role files into the role directory' do
                  repo_path.join('librarian_roles/level_one/meta/main.yml').should exist
                end
              end
              context 'level_two' do
                it 'should create the directory for the role ' do
                  repo_path.join('librarian_roles/level_two').should exist
                end

                it 'should copy the role files into the role directory' do
                  repo_path.join('librarian_roles/level_two/meta/main.yml').should exist
                end
              end
            end
          end
        end
      end
    end
  end
end
