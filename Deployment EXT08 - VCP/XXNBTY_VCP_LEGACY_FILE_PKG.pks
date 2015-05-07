create or replace PACKAGE       XXNBTY_EXT08_VCP_FILE_VAL_PKG --5/7/2015 AFlores

----------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_EXT08_VCP_FILE_VAL_PKG
Author's Name: Erwin Ramos
Date written: 04-May-2015
RICEFW Object: N/A
Description: Package will execute the . 
             This output file will be sent to identified recipient(s) using UNIX program.
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
04-May-2015				 	Erwin Ramos				Initial Development
07-May-2015					Albert Flores			Applied standards

*/
--------------------------------------------------------------------------------------------
AS 

  --main procedure that will call another concurrent program to execute the checking. 
  PROCEDURE exec_concurrent_main ( x_errbuf              	OUT VARCHAR2
								  ,x_retcode             	OUT VARCHAR2 
								  ,p_retries 				NUMBER 		--5/7/2015 AFlores
								  ,p_interval				NUMBER 		--5/7/2015 AFlores
								  ,p_location				VARCHAR2	--5/7/2015 AFlores
								  ,p_ebs_program			VARCHAR2);  --5/7/2015 AFlores
							 
  --Procedure to generate email. 
  PROCEDURE generate_email ( x_errbuf   	  OUT VARCHAR2
							,x_retcode 		  OUT VARCHAR2
							,p_new_filename   VARCHAR2
							,p_old_filename   VARCHAR2
							,p_lookup_name    VARCHAR2
							,p_subject		  VARCHAR2
							,p_message		  VARCHAR2);

END XXNBTY_EXT08_VCP_FILE_VAL_PKG; --5/7/2015 AFlores

/

show errors; 


