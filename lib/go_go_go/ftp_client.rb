require "net/ftp"

class FtpClient
    public
    def initialize(host, username, password)
        @host = host
        @username = username
        @password = password
        
        connect
    end
    
    private
    def connect
        begin
            @ftp = Net::FTP.open(@host, @username, @password)
        rescue => e
            raise StandardError.new("Connection to remote FTP host failed: #{e.message}")
        end
    end
    
    private
    def check_connection
        if @ftp.closed?
            connect
        end
    end
    
    public
    def upload_file(local_file_path, remote_file_path)
        check_connection
        
        begin
            @ftp.putbinaryfile(local_file_path, remote_file_path)
        rescue => e
            return e.message
        end
        
        return true
    end
    
    public
    def create_directory(remote_path)
        check_connection
        
        begin
            @ftp.mkdir(remote_path)
        rescue => e
            return e.message
        end
        
        return true
    end
    
    public
    def delete_file(remote_file_path)
        check_connection
        
        begin
            @ftp.delete(remote_file_path)
        rescue => e
            return e.message
        end
        
        return true
    end
    
    public
    def delete_directory(remote_path)
        check_connection
        
        begin
            @ftp.chdir(remote_path) #- Get inside directory
            
            #--- Iterate files and folders
            @ftp.ls.each do |line|
                item_name = line.split(" ")[8..-1].join(" ")
                
                if item_name != "." and item_name != ".."
                    if line[0].chr == "d" #- This should be a directory
                        delete_directory(remote_path + "/" + item_name)
                    elsif line[0].chr == "-" #- This should be a file
                        @ftp.delete(remote_path + "/" + item_name)
                    else
                        #- This must be garbage. So do nothing
                    end
                end
            end
            
            @ftp.rmdir(remote_path) #- Finally, delete the (now empty) root directory itself
        rescue => e
            return e.message
        end
        
        return true
    end

    # No error handling is done this method deliberately.
    # Do it while you call it.
    public
    def download_and_read_file(remote_file_path)
        check_connection
        
        begin #- This error handling is for deleting a local temp file that will be created even if the getbinaryfile fails
            @ftp.getbinaryfile(remote_file_path)
        rescue => e
            File.delete(File.basename(remote_file_path))
            raise e
        end
        
        local_temp_file = File.basename(remote_file_path)
        data = File.read(local_temp_file)
        File.delete(local_temp_file) #- Delete the temp file after reading it
        
        return data
    end
    
    public
    def write_file_and_upload(remote_file_path, data)
        local_temp_file = File.basename(remote_file_path)
        
        begin
            File.open(local_temp_file, 'w') {|f| f.write(data)}
        rescue => e
            return e.message
        end
        
        check_connection
        begin
            @ftp.putbinaryfile(local_temp_file, remote_file_path)
        rescue => e
            return e.message
        end

        begin
            File.delete(local_temp_file)
        rescue => e
            return e.message
        end
        
        return true
    end
    
    public
    def dispose
        @ftp.quit
        @ftp.close
    end
end