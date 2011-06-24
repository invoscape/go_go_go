require File.join(File.dirname(__FILE__), "go_go_go/ftp_client")
require "logger"
require 'yaml'

class GoGoGo
    APPLICATION_ROOT = Dir.pwd
    SETTINGS = YAML::load(File.open("#{APPLICATION_ROOT}/config/go_go_go.yml"))
    FTP_HOST = SETTINGS["ftp_host"]
    FTP_USERNAME = SETTINGS["ftp_username"]
    FTP_PASSWORD = SETTINGS["ftp_password"]
    APPLICATION_PATH_IN_SERVER = SETTINGS["application_path_in_server"]
    
    public
    def initialize(from_revision = nil, to_revision = nil)
        @from_revision = from_revision
        @to_revision = to_revision
        @log = Logger.new(APPLICATION_ROOT + "/log/go_go_go.log")
        
        #--- Perform steps
        check_if_source_code_is_ready
        determine_last_release_revision_number
        compose_change_list
        start_uploading
        record_current_release_revision_number
    end
    
    private
    def check_if_source_code_is_ready
        show_message ""
        show_message "STEP 1: Check if source code is ready for release"
        
        lines = IO.popen("svn status -u").readlines
        
        #--- Check if there are any pending updates and commits
        is_updates_pending = false
        is_commits_pending = false
        lines[0..-2].each do |line|
            if line.include? "*"
                is_updates_pending = true
            else
                is_commits_pending = true
            end
        end
        
        #--- Print appropriate error messages and exit
        if is_updates_pending == true or is_commits_pending == true
            if is_updates_pending == true
                show_message " - ERROR: Your source is not up to date"
            end
            if is_commits_pending == true
                show_message " - ERROR: You have uncommitted change(s). Please commit and try again"
            end
            exit
        end
        
        #--- Know the HEAD revision
        @head_revision = lines.last.split(" ").last.strip.to_i
        
        show_message " - It's up to date"
        show_message " - Everything's committed"
    end
    
    private
    def determine_last_release_revision_number
        show_message ""
        show_message "STEP 2: Determine last release's SVN revision number"
        
        if not @from_revision.nil?
            show_message " - It was #{@from_revision}"
            @yaml_hash = {"release_history" => []} #- Initialize an empty yaml hash to be used later to record current release's revision
        else
            show_message " - Trying to get it from go_go_go.yml in server..."
            
            #--- Try to get it from server
            begin
                @ftp_client = FtpClient.new(FTP_HOST, FTP_USERNAME, FTP_PASSWORD)
                @yaml_hash = YAML::load(@ftp_client.download_and_read_file(APPLICATION_PATH_IN_SERVER + "/go_go_go.yml"))
                @from_revision = @yaml_hash["release_history"].last["release"]["svn_revision"]
                date_time = @yaml_hash["release_history"].last["release"]["date"].strftime(" %d %b %Y, %A, %I:%M:%S %p")
                @ftp_client.dispose
            rescue => e
                show_message " - ERROR: Retrieving it from server failed. However you can specify it manually by using 'rake gogogo:release_from[<revision>]'"
                show_message " - ERROR DESCRIPTION: #{e.message}"
                exit
            end
            
            show_message " - Last release was made on #{date_time} and the revision number was #{@from_revision}"
        end
    end
    
    private
    def compose_change_list
        #--- Determine to_revision
        if @to_revision.nil?
            @to_revision = @head_revision
        end
        
        show_message ""
        show_message "STEP 3: Check changes between revisions #{@from_revision} and #{@to_revision} #{@to_revision == @head_revision ? '(HEAD)' : nil}"
        
        @change_list = []
        lines = IO.popen("svn diff --revision #{@from_revision}:#{@to_revision} --summarize").readlines
        
        #--- Iterate in reverse order through the list returned by SVN because only reverse order seems to be a sensible sequence of events
        i = 0
        lines.reverse_each do |line|
            i += 1
            
            case line[0].chr
                when "A"
                action = :add
                when "M"
                action = :update
                when "D"
                action = :delete
            else
                action = :update
            end
            
            file_path = line[8..-1].chomp.gsub("\\", "/")
            local_file_path = APPLICATION_ROOT + "/" + file_path
            remote_file_path = APPLICATION_PATH_IN_SERVER + "/" + file_path
            
            @change_list.push({:action => action, :local_file_path => local_file_path, :remote_file_path => remote_file_path})
            
            show_message " - #{i.to_s.ljust(4, ' ')} #{action.to_s.upcase.ljust(6, ' ')} #{file_path}"
        end
        
        #--- Print error message and abort if no change is found
        if @change_list.empty?
            show_message " - ERROR: No change has occurred"
            exit
        end
    end
    
    public
    def start_uploading
        show_message ""
        show_message "STEP 4: Start FTPing (starting at #{Time.now} )"
        print " - Connecting to server..."
        
        @ftp_client = FtpClient.new(FTP_HOST, FTP_USERNAME, FTP_PASSWORD)
        @is_all_ftp_operations_successful = true #- Set flag as true initially
        
        show_message " Done"
        
        @change_list.each_with_index do |change, i|
            show_message ""
            show_message " > #{(i + 1).to_s.ljust(4, ' ')} #{change[:action].to_s.upcase} #{change[:remote_file_path]}"
            
            #--- Add
            if change[:action] == :add
                if File.directory? change[:local_file_path]
                    result = @ftp_client.create_directory(change[:remote_file_path])
                else
                    result = @ftp_client.upload_file(change[:local_file_path], change[:remote_file_path])
                end
                print_ftp_operation_result(result)
            end
            
            #--- Update
            if change[:action] == :update
                if File.directory? change[:local_file_path]
                    #- Nothing to update in a folder
                else
                    result = @ftp_client.upload_file(change[:local_file_path], change[:remote_file_path])
                end
                print_ftp_operation_result(result)
            end
            
            #--- Delete
            if change[:action] == :delete
                #--- Try to delete the item as a file
                result = @ftp_client.delete_file(change[:remote_file_path])
                
                #--- Try to delete the item as a directory if the earlier attempt failed
                if result != true
                    result = @ftp_client.delete_directory(change[:remote_file_path])
                end
                
                print_ftp_operation_result(result)
            end
        end
        show_message ""
        show_message "Release finished at #{Time.now}"
        show_message ""
        
        @ftp_client.dispose
    end
    
    private
    def print_ftp_operation_result(result)
        if result == true
            show_message " #{200.chr}#{175.chr} Success"
        else
            @is_all_ftp_operations_successful = false
            show_message " #{200.chr}#{175.chr} ERROR: #{result}"
        end
    end
    
    private
    def record_current_release_revision_number
        show_message ""
        show_message "STEP 5: Record current release's SVN revision number"
        
        #--- Add the to_revision as the currently released revision in the yaml_hash
        release = {"release" => {"date" => Time.now, "svn_revision" => @to_revision, "with_errors" => @is_all_ftp_operations_successful}}
        release_history_array = @yaml_hash["release_history"].push(release).reverse[0..99].reverse #- Retain only last 100 items
        @yaml_hash["release_history"] = release_history_array

        #--- Write data to server
        @ftp_client = FtpClient.new(FTP_HOST, FTP_USERNAME, FTP_PASSWORD)
        result = @ftp_client.write_file_and_upload(APPLICATION_PATH_IN_SERVER + "/go_go_go.yml", YAML::dump(@yaml_hash))
        @ftp_client.dispose
        
        #--- Show result of recording revision number
        if result == true
            show_message " - Successfully updated go_go_go.yml in server with revision number #{@to_revision}"
        else
            show_message " - ERROR: #{result}"
            show_message " - NOTE: Check if the release information has been successfully written in go_go_go.yml in the server. If not, try to update it manually with the revision number #{@to_revision}"
        end
        
        #--- Show success/failure of the release
        if @is_all_ftp_operations_successful
            show_message ""
            show_message ""
            show_message "********************************************"
            show_message "You have successfully made a gogogo release!"
            show_message "********************************************"
            show_message ""
        else
            show_message " - ERROR: All FTP operations didn't complete successfully. Try to manually correct the error(s)."
            show_message ""
            show_message ""
            show_message "-----------------------------------------------------------------------"
            show_message "You have made a gogogo release with error(s). Try to fix them manually!"
            show_message "-----------------------------------------------------------------------"
            show_message ""
        end
    end
    
    private
    def show_message(message)
        puts message
        @log.info message
    end
end