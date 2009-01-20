#           NAME: sinatra-cas
#        VERSION: 0.1.1 (Jan 19, 2008)
#         AUTHOR: Galin Yordanov <gyordanov@gmail.com> Nabbr Corp
#    DESCRIPTION: CAS plugin for Sinatra apps
#  COMPATIBILITY: - Sinatra 0.9.0.2
#        LICENSE: Apache License, Version 2.0
#
#   INSTRUCTIONS: 

# ====== DEFAULT OPTIONS FOR PLUGIN ====== 
module Sinatra
  module Plugins
    module CAS
      OPTIONS = {
        :enabled         => true,
        :cas_server_url  => nil,
        :session_timeout => 14400
      }
    end
  end
end


module Sinatra
  module Plugins
    module CAS
      helpers do
        def login_required?
          return false if request.env['REQUEST_URI'] =~ /^\/extjs\/|^\/js\/|^\/css\//
          return false if request.env['PATH_INFO'] =~ /.css$|.jpg$|.png$|.gif$|.json$/
          return true
        end

        def get_serice_url
          surl = (request.env['rack.url_scheme'] + "://"+request.env['HTTP_HOST'] + request.env['REQUEST_URI'])
          surl = surl.gsub(/service=[^&]*[&]?/,'').gsub(/ticket=[^&]*[&]?/,'').gsub(/logout?/,'').gsub(/logout/,'')
          surl.gsub(/\?$/,'')
        end

        def logout_url
          client = CASClient::Client.new({:cas_base_url => Plugins::CAS::OPTIONS[:cas_server_url]})
          client.logout_url(get_serice_url,get_serice_url)
        end

        def logout
          session.delete :cas_username
          redirect logout_url
        end

        def login
          if ! login_required? && ! Plugins::CAS::OPTIONS[:enabled]
            return nil
          end
          client = CASClient::Client.new({:cas_base_url => Plugins::CAS::OPTIONS[:cas_server_url]})
          caslogin_url = client.add_service_to_login_url(get_serice_url)
          params = nested_params(request.params)
          if params[:ticket]
            if params[:ticket] =~ /^PT-/
              st = CASClient::ProxyTicket.new(params[:ticket], get_serice_url, params[:renew])
            else
              st = CASClient::ServiceTicket.new(params[:ticket], get_serice_url, params[:renew])
            end
            client.validate_service_ticket(st)
            if st.is_valid?
              yield st.response.user if block_given?
              params[:cas_username] = st.response.user
              session[:cas_username] = st.response.user
              session[:cas_last_valid_ticket] = Time.now.to_i
              redirect get_serice_url
            else
              redirect caslogin_url
            end
          else
            if session[:cas_username]
              session[:cas_last_valid_ticket] = Time.now.to_i unless session.has_key? :cas_last_valid_ticket
              time_ago = Time.now.to_i - session[:cas_last_valid_ticket]
              if time_ago > 14400
                session.delete :cas_username
                redirect caslogin_url
              else
                session[:created_at] = Time.now.to_i
                params.merge!(session)
              end
            else
              # go ahead and redirect to the cas
              redirect caslogin_url
            end
          end
          @cas_username = params[:cas_username]
        end
      end
    end
  end
end

Sinatra::Base.send(:include, Sinatra::Plugins::CAS)
