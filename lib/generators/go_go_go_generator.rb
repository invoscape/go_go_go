class GoGoGoGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)
    def settings
        copy_file "go_go_go.yml", "config/go_go_go.yml"
    end  
end
