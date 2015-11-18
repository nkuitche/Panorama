# encoding: utf-8
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'application_helper' # Erweiterung der Controller um Helper-Methoden
include ActionView::Helpers::JavaScriptHelper      # u.a. zur Nutzung von escape_javascript(j) im Controllern

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  #protect_from_forgery with: :exception                  # cross site scripting verhindern
  protect_from_forgery with: :null_session               # cross site scripting verhindern


  #force_ssl


  include ApplicationHelper # Erweiterung der Controller um Helper-Methoden des GUI's 

  # open_connection immer ausfuehren, ausser bei auswahl der Connection selbst
  before_filter :open_connection # , :except -Liste wird direkt in open_connection gehandelt
  after_filter  :after_request

  rescue_from Exception, :with => :global_exception_handler

  # Abfangen aller Exceptions während Verarbeitung von Controller-Actions
  def global_exception_handler(exception)
    close_connection  # Umsetzen der Connection auf NullDB bei Auftreten von Exception während Verarbeitung (after_Filter wird nicht mehr durchlaufen)

    #respond_to do |format|
    #  format.js {render :js => "$('#list_segment_stat_hist_sum_area').html('#{j render_to_string :partial=>"list_segment_stat_historic_sum" }');" }
    #end

    @exception = exception                                                      # Sichtbarkeit im template
    @request   = request

    Rails.logger.error @exception.class.name
    if @request.parameters['controller']
      Rails.logger.error "#{@request.parameters['controller'].camelize}Controller#{"##{@request.parameters['action']}" if @request.parameters['action'] }"
    end

    Rails.logger.error @exception.message

    curr_line_no=0
    @exception.backtrace.each do |bt|
      Rails.logger.error bt if curr_line_no < 20                                # report First 20 lines of stacktrace in log
      curr_line_no += 1
    end


    render :partial =>'application/error_message', :status=>500

    #raise exception   # Standard-Behandlung der Exceptions
  end

  # Ausführung vor jeden Request
  def open_connection
    current_database = read_from_client_info_store(:current_database)
    current_database.symbolize_keys! if current_database && current_database.class.name == 'Hash'   # Sicherstellen, dass Keys wirklich symbole sind. Bei Nutzung Engine in App erscheinen Keys als Strings

    I18n.locale = get_locale                                                    # fuer laufende Action Sprache aktivieren

    # Auuschluss von Methoden, die keine DB-Connection bebötigen
    # Präziser before_filter mit Test auf controller
    return if (controller_name == 'env' && ['index', 'get_tnsnames_records', 'set_locale', 'set_database_by_params', 'set_database_by_id'].include?(action_name) )                  ||
              (controller_name == 'dba_history' && action_name == 'getSQL_ShortText') ||  # Nur DB-Connection wenn Cache-Zugriff misslingt
    (controller_name == 'dragnet' && ['refresh_selected_data', 'get_selection_list'].include?(action_name) )  ||
              (controller_name == 'usage' && ['info', 'detail_sum', 'single_record', 'ip_info'].include?(action_name) )


    # Letzten Menü-aufruf festhalten z.B. für Hilfe
    write_to_client_info_store(:last_used_menu_controller, params[:last_used_menu_controller]) if params[:last_used_menu_controller]
    write_to_client_info_store(:last_used_menu_action    , params[:last_used_menu_action])     if params[:last_used_menu_action]
    write_to_client_info_store(:last_used_menu_caption   , params[:last_used_menu_caption])    if params[:last_used_menu_caption]
    write_to_client_info_store(:last_used_menu_hint      , params[:last_used_menu_hint])       if params[:last_used_menu_hint]

    # Bis hierher aktive Connection ist Dummy mit NullDB

    # Neue Connection auf Basis Oracle aufbauen mit durch Anwender gegebener DB
    if current_database
      # Initialisierungen

      # Protokollieren der Aufrufe in lokalem File
      real_controller_name = params[:last_used_menu_controller] ? params[:last_used_menu_controller] : controller_name
      real_action_name     = params[:last_used_menu_action]     ? params[:last_used_menu_action]     : action_name

      open_oracle_connection   # Oracle-Connection aufbauen

      begin
        # Ausgabe Logging-Info in File für Usage-Auswertung
        filename = Panorama::Application.config.usage_info_filename
        File.open(filename, 'a'){|file| file.write("#{request.remote_ip} #{ConnectionHolder.current_database_name} #{Time.now.year}/#{"%02d" % Time.now.month} #{real_controller_name} #{real_action_name} #{Time.now.strftime('%Y/%m/%d-%H:%M:%S')} #{database_helper_raw_tns}\n")}
      rescue Exception => e
        logger.warn("#### ApplicationController.open_connection: Exception beim Schreiben in #{filename}: #{e.message}")
      end

      # Registrieren mit Name an Oracle-DB
      #ConnectionHolder.connection().execute("call dbms_application_info.set_Module('Panorama', '#{controller_name}/#{action_name}')")
      ConnectionHolder.connection().exec_update("call dbms_application_info.set_Module('Panorama', :action)", nil,
                                                  [[ActiveRecord::ConnectionAdapters::Column.new(':action', nil, ActiveRecord::Type::Value.new), "#{controller_name}/#{action_name}"]]
      )

      #ConnectionHolder..connection.exec_update("call dbms_application_info.set_Module('Panorama', ?)", nil, ["#{controller_name}/#{action_name}"])

    else  # Keine DB bekannt
       raise t(:application_connection_no_db_choosen, :default=> 'No DB choosen! Please connect to DB by link in right upper corner. (Browser-cookies are required)')
    end

    # Request-Counter je HTML-Session als Hilsmittel für eindeutige html-IDs
    session[:request_counter] = 0 unless session[:request_counter]
    session[:request_counter] += 1
  rescue Exception=>e
    set_dummy_db_connection                                                     # Sicherstellen, dass für nächsten Request gültige Connection existiert
    raise # "Error while connecting to #{database_helper_raw_tns}"         # Explizit anzeige des Connect-Problemes als Popup-Message
  end

  # Aktivitäten nach Requestbearbeitung
  def after_request
    # Letzte Connection offen lassen
    # close_connection   # Sicherstellen, dass naechster Request nicht mit der aktuellen Connection einfach weiter macht
  end

  # Ausfüherung nach jedem Request ohne Ausnahme
  def close_connection
    set_dummy_db_connection
  end


protected  
  # Ausgabe der Meldungen einer Exception
  def alert(exception, header='')
    if exception
      logger.error exception.message
      exception.backtrace.each do |bt|
        logger.error bt
      end
      message = exception.message
      message << "\n\n"
      #message << caller.to_s
      exception.backtrace.each do |bt|
        message << bt
      end
    else
      message = 'ApplicationController.alert: Exception = nil'
    end
    respond_to do |format|
      format.js { render :js => "alert('#{j "#{header}\n\n#{message}"}');" } # Optional zu erweitern um caller.to_s
    end

  end


  # Ausgabe einer Popup-Message,
  # Nach Aufruf von show_popup_message muss mittels return die Verarbeitung der Controller-Methode abgebrochen werden (Vermeiden doppeltes rendern)

  def show_popup_message(message)
    respond_to do |format|
      format.js { render :js => "alert('#{j "#{message}"}');" }
    end

  end
  
end
