require File.join(File.dirname(__FILE__), "..", "go_go_go")

namespace :gogogo do
    task :release do
        GoGoGo.new
    end
    
    task :release_upto, [:to_revision] do |t, args|
        to_revision = args.to_revision.to_i
        if to_revision == 0
            puts
            puts "ERROR: Provide a valid SVN revision number upto which you want to make the release (from last release's revision)"
            puts
            exit
        end
        
        GoGoGo.new(nil, to_revision)
    end
    
    task :release_from, [:from_revision] do |t, args|
        from_revision = args.from_revision.to_i
        if from_revision == 0
            puts
            puts "ERROR: Provide a valid SVN revision number from which you want to make the release (upto HEAD revision)"
            puts
            exit
        end
        
        GoGoGo.new(from_revision, nil)
    end
    
    task :release_from_upto, [:from_revision, :to_revision] do |t, args|
        from_revision = args.from_revision.to_i
        to_revision = args.to_revision.to_i
        if from_revision == 0 or to_revision == 0
            puts
            puts "ERROR: Provide valid SVN revision numbers between which you want to make the release for changes"
            puts
            exit
        end
        
        GoGoGo.new(from_revision, to_revision)
    end
end