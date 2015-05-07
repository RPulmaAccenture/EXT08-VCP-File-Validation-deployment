create or replace PACKAGE BODY       XXNBTY_EXT08_VCP_FILE_VAL_PKG --5/7/2015 AFlores

----------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_EXT08_VCP_FILE_VAL_PKG
Author's Name: Erwin Ramos
Date written: 04-May-2015
RICEFW Object: N/A
Description: Package will execute the UNIX program for Flat File Validation. If there are any
			 missing files, it will generate an output file with the details. This program will
			 also check if the EBS interface request set was executed or has encountered an error.
             This output file will be sent to identified recipient(s) using UNIX program.
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
04-May-2015				 	Erwin Ramos				Initial Development
07-May-2015					Albert Flores			Applied standards / Additional Parameters
*/
--------------------------------------------------------------------------------------------



IS
  --main procedure that will call XXNBTY_VCP_LEG_FILE_VAL concurrent program
  PROCEDURE exec_concurrent_main (x_errbuf              	OUT VARCHAR2
								 ,x_retcode             	OUT VARCHAR2
								 ,p_retries 				NUMBER		--5/7/2015 AFlores
								 ,p_interval				NUMBER      --5/7/2015 AFlores
								 ,p_location				VARCHAR2    --5/7/2015 AFlores
								 ,p_ebs_program				VARCHAR2	--5/7/2015 AFlores
							 )
  IS 
    TYPE c_num 			IS REF CURSOR;
	c_ebs_req_load      c_num;
    v_request_id    	fnd_concurrent_requests.request_id%TYPE; 
	v_status_code		fnd_concurrent_requests.status_code%TYPE;
	v_completion_text	fnd_concurrent_requests.completion_text%TYPE;
	v_logfile_name		fnd_concurrent_requests.logfile_name%TYPE;
	dbLink           	msc_apps_instances.M2A_DBLINK%TYPE;
	v_instance_id	   	msc_apps_instances.INSTANCE_ID%TYPE;
	v_executed			VARCHAR2(10);
	v_subject       	VARCHAR2(100);
    v_message       	VARCHAR2(1000);
	v_lookup_name   	VARCHAR2(100);
	v_new_filename		VARCHAR2(100);
	query_str        	VARCHAR2(1000);
	ln_request_id 		NUMBER;
	ln_wait             BOOLEAN;
	lc_phase            VARCHAR2(100)   := NULL;
	lc_status           VARCHAR2(30)    := NULL;
	lc_devphase         VARCHAR2(100)   := NULL;
	lc_devstatus        VARCHAR2(100)   := NULL;
	lc_mesg             VARCHAR2(50)    := NULL;
	le_error 			EXCEPTION;
	le_ebs_validation 	EXCEPTION;
	v_ebs_program       VARCHAR2(240)  := UPPER(p_ebs_program); --5/7/2015 AFlores
	
	CURSOR c_ebsdbLink
	IS
	  SELECT M2A_DBLINK
			,INSTANCE_ID
		FROM msc_apps_instances
	   WHERE instance_code = 'EBS';
	 
	CURSOR c_logid (p_request_id number)
	IS
		SELECT status_code
		,completion_text
		,logfile_name
        FROM fnd_concurrent_requests
        WHERE request_id = p_request_id;

  BEGIN  
  
	--Cursor to call EBS DBLINK
	 OPEN c_ebsdbLink;
	 FETCH c_ebsdbLink 
		INTO dbLink
			,v_instance_id;
	 CLOSE c_ebsdbLink;
     --5/7/2015 AFlores
	 query_str := 'SELECT fcr.status_code 
        FROM fnd_concurrent_requests@'|| dbLink ||' fcr
        WHERE UPPER(fcr.description) = ''' || v_ebs_program || '''
        AND TRUNC(fcr.actual_completion_date) = TRUNC(SYSDATE)
        AND fcr.status_code = ''C''';
	 --5/7/2015 AFlores--End
	 FND_FILE.PUT_LINE(FND_FILE.LOG, 'CHECK the query_str:' || query_str);
	 v_executed := 'E';
	 v_lookup_name := 'XXNBTY_VCP_COLL_REP_ADD_LKP';
	
	 OPEN c_ebs_req_load FOR query_str;
       FETCH c_ebs_req_load 
			INTO v_executed;
	 CLOSE c_ebs_req_load;	
	
		--v_lookup_name := 'XXNBTY_VCP_COLL_REP_ADD_LKP';
		--v_new_filename := 'XXNBTY_VCP_FILE_VALIDATION_' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '.txt';
	
        IF v_executed = 'C' 
		THEN
        --To call the XXNBTY_EBS_LEG_FILE_VAL concurrent program
			v_request_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'XXNBTY'
												   ,program      => 'XXNBTY_VCP_LEGACY_FILE_VAL'
												   ,start_time   => TO_CHAR(SYSDATE,'DD-MON-YYYY HH:MI:SS')
												   ,sub_request  => FALSE
												   ,argument1    => p_retries
												   ,argument2    => p_interval
												   ,argument3    => p_location
													);
			FND_CONCURRENT.AF_COMMIT;
			
			ln_wait := fnd_concurrent.wait_for_request( request_id      => v_request_id
													   , interval        => 30
													   , max_wait        => ''
													   , phase           => lc_phase
													   , status          => lc_status
													   , dev_phase       => lc_devphase
													   , dev_status      => lc_devstatus
													   , message         => lc_mesg
													   );
		
				   IF UPPER(lc_devstatus) = 'NORMAL' AND UPPER(lc_devphase) = 'COMPLETE'
					 THEN
						FND_FILE.PUT_LINE(FND_FILE.LOG, 'XXNBTY_VCP_LEG_FILE_VAL concurrent program completed successfully');
						x_retcode := 0;
				   ELSE
				
						FND_FILE.PUT_LINE(FND_FILE.LOG,'XXNBTY_VCP_LEG_FILE_VAL request id : '|| v_request_id);

						--Cursor to select the status_code, completion_text, logfile_name
						OPEN c_logid(v_request_id); 
						FETCH c_logid 
							INTO v_status_code
								,v_completion_text
								,v_logfile_name; 
						CLOSE c_logid; 
						
						FND_FILE.PUT_LINE(FND_FILE.LOG,'XXNBTY_VCP_LEG_FILE_VAL log file : '|| v_logfile_name);
						FND_FILE.PUT_LINE(FND_FILE.LOG,'XXNBTY_VCP_LEG_FILE_VAL status code : '|| v_status_code);
						FND_FILE.PUT_LINE(FND_FILE.LOG,'XXNBTY_VCP_LEG_FILE_VAL completion text : '|| v_completion_text);
												
						v_new_filename := 'XXNBTY_FILE_VALIDATION_' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '.txt';
						
						FND_FILE.PUT_LINE(FND_FILE.LOG,'START to call generate email');
			  
						IF v_status_code = 'E'
						THEN	
							v_subject := 'Supply Planning - VCI Data has missing legacy flat files.';
							v_message := 'Hi, \n\nThere is/are missing Legacy Flat File/s in the ' ||p_location ||' .\n\n***** This is an auto-generated e-mail.  Please do not reply.  If you have any questions, call the HelpDesk. *****';
		
							generate_email(x_retcode
										,x_errbuf
										,v_new_filename
										,v_logfile_name
										,v_lookup_name
										,v_subject
										,v_message
										);
						  RAISE le_error;
						ELSE 
							FND_FILE.PUT_LINE(FND_FILE.LOG,'XXNBTY FILE VALIDATION all Legacy Flat File are in the ' ||p_location);
							x_retcode := 0;
				
						END IF;
					END IF;
		
				FND_FILE.PUT_LINE(FND_FILE.LOG,'The value of x_retcode is : ' ||x_retcode);       
		ELSE -- If the EBS INT REQUEST SET load did not execute for today. 
			v_subject := 'Supply Planning - EBS Request Set was not processed or has an error';
			v_message := 'Hi, \n\nThe '|| v_ebs_program ||' was not executed or has encountered an error for '|| TO_CHAR(SYSDATE, 'DD-MON-YYYY') || '.\n\n*****This is an auto-generated e-mail.  Please do not reply.  If you have any questions, call the HelpDesk.*****';
			v_new_filename := 'NONE';
			v_logfile_name := 'NONE';
			generate_email(x_retcode
					,x_errbuf
					,v_new_filename
					,v_logfile_name
					,v_lookup_name
					,v_subject
					,v_message
					);
				 RAISE le_ebs_validation;
			 
        END IF;  
		
	EXCEPTION
	WHEN le_error THEN 
		x_errbuf := 'XXNBTY FILE VALIDATION missing Legacy Flat File in the ' ||p_location;
		x_retcode := 2;
		FND_FILE.PUT_LINE(FND_FILE.LOG,'XXNBTY FILE VALIDATION missing Legacy Flat File in the ' ||p_location);
		
	WHEN le_ebs_validation THEN 
		x_errbuf := 'The EBS INT Request set was not executed today ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY');
		x_retcode := 2;
		FND_FILE.PUT_LINE(FND_FILE.LOG,'The EBS INT Request set was not executed today ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY'));
	
	WHEN OTHERS THEN
		x_errbuf := SQLERRM;
		x_retcode := 2;
		FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || x_errbuf);	
	
   END exec_concurrent_main;

  PROCEDURE generate_email (x_errbuf    OUT VARCHAR2
						,x_retcode   OUT VARCHAR2
                        ,p_new_filename VARCHAR2
                        ,p_old_filename VARCHAR2
                        ,p_lookup_name  VARCHAR2
						,p_subject		VARCHAR2
						,p_message		VARCHAR2)
  IS
  
  --------------------------------------------------------------------------------------------
  /*
  Procedure Name: generate_email
  Author's Name: Mark Anthony Geamoga
  Date written: 19-Dec-2014
  RICEFW Object: N/A
  Description: Procedure for generate email procedure that will send access error log file and send it to recipients using lookups. 
  Program Style:
  Maintenance History:
  Date         Issue#  Name         			    Remarks
  -----------  ------  -------------------		------------------------------------------------
  19-Dec-2014          Mark Anthony Geamoga  	Initial Development

  */
  --------------------------------------------------------------------------------------------
    v_request_id    NUMBER;
    v_subject       VARCHAR2(100);
    v_message       VARCHAR2(1000);
    lp_email_to     VARCHAR2(1000);
    lp_email_to_cc  VARCHAR2(1000);
    lp_email_to_bcc VARCHAR2(1000);
	
    CURSOR cp_lookup_email_ad (p_lookup_name VARCHAR2, p_tag VARCHAR2) --lookup for recipient(s)
    IS
       SELECT meaning
        FROM fnd_lookup_values
       WHERE lookup_type = p_lookup_name
         AND enabled_flag = 'Y'
         AND UPPER(tag) = p_tag
         AND SYSDATE BETWEEN start_date_active AND NVL(end_date_active,SYSDATE);

  BEGIN

    --check all direct recipients in lookup
    FOR rec_send IN cp_lookup_email_ad (p_lookup_name, 'TO')
    LOOP
      lp_email_to := LTRIM(lp_email_to||','||rec_send.meaning,',');
    END LOOP;

    --check all cc recipients in lookup
    FOR rec_send_cc IN cp_lookup_email_ad (p_lookup_name, 'CC')
    LOOP
      lp_email_to_cc := LTRIM(lp_email_to_cc||','||rec_send_cc.meaning,',');
    END LOOP;

    --check all bcc recipients in lookup
    FOR rec_send_bcc IN cp_lookup_email_ad (p_lookup_name, 'BCC')
    LOOP
      lp_email_to_bcc := LTRIM(lp_email_to_bcc||','||rec_send_bcc.meaning,',');
    END LOOP;
	
	v_subject := p_subject;
	v_message := p_message;
		
    FND_FILE.PUT_LINE(FND_FILE.LOG,'New Filename : ' || p_new_filename);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Old Filename : ' || p_old_filename);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Direct Recipient : ' || lp_email_to);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Carbon Copy Recipient : ' || lp_email_to_cc);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Blind Carbon Copy Recipient : ' || lp_email_to_bcc);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Email Subject : ' || v_subject);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Email Content : ' || v_message);

    IF lp_email_to_bcc IS NOT NULL AND lp_email_to_cc IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Cannot proceed in sending email due to BCC recipient contains a value and CC recipient is missing.');
    ELSE --send email if recipient is valid.
    --get request id generated after running concurrent program
    v_request_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'XXNBTY'
                                               ,program      => 'XXNBTY_VCP_SEND_EMAIL_LOG'
                                               ,start_time   => TO_CHAR(SYSDATE,'DD-MON-YYYY HH:MI:SS')
                                               ,sub_request  => FALSE
                                               ,argument1    => p_new_filename
                                               ,argument2    => p_old_filename
                                               ,argument3    => lp_email_to
                                               ,argument4    => lp_email_to_cc
                                               ,argument5    => lp_email_to_bcc
                                               ,argument6    => v_subject
                                               ,argument7    => v_message 
                                               );
    FND_CONCURRENT.AF_COMMIT;
    END IF;

    FND_FILE.PUT_LINE(FND_FILE.LOG,'Request ID of XXNBTY_SendEmailLog : ' || v_request_id);

    IF v_request_id != 0 THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Sending successful.');
    ELSE
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in sending email.');
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      x_retcode := 2;
      x_errbuf := SQLERRM;
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || x_errbuf);
  END generate_email;

END XXNBTY_EXT08_VCP_FILE_VAL_PKG; --5/7/2015 AFlores

/

show errors;


