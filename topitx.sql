-- SAGEMAKER
-- ARN for Platform Prod: arn:aws:iam::487651640582:role/dbadmin_policy

-- Approach will be to find some 'troublsome panel serial numbers' and make a native Redshift table
-- with what are thought to be the relevent columns from panel_telemetry and MDM tables (inner joined)
-- then use the data in this table for training.
-- After the model is trained and built, create a view for the 'test data' to run the model against.


-- top 500 panel event counts from Mixpanel
-- INSERT INTO trouble_panels (panel_serial_number,event_count) values ('775T-JC2U3A2470372','281601');
-- the rest are in populate_trouble_panels.sql
insert into trouble_panels (select "panel serial number" as panel_serial_number, count(event)::bigint as event_count from s3_external_schema.panel_telemetry where year = 2025 and month = 3 group by  "panel serial number" order by  count(event) desc limit 575);

drop table if exists trouble_panels_ml_mdm_config_train;
create table trouble_panels_ml_mdm_config_train (
panel_serial_number varchar(255),
hieventcountlikely boolean,
event_count bigint,
app_build_number varchar(255),
app_release varchar(255),
app_version varchar(255),
os varchar(255),    
os_version varchar(255), 
"platform_name" varchar(255),    
"platform_version" varchar(255), 
usb_device_manufacturer varchar(255), 
bezel_description varchar(255),
reporting_app_name varchar(255) ,
product_name varchar(255)           
) DISTSTYLE AUTO;

INSERT INTO trouble_panels_ml_mdm_config_train (
SELECT tp.panel_serial_number, null as hieventcountlikely, tp.event_count::bigint as event_count, 
"$app_build_number" as app_build_number,
"$app_release" as app_release,
"$app_version" as app_version,
"$os" as os ,    
"$os_version" as os_version, 
"platform_name",    
"platform_version" , 
"usb-device manufacturer" as usb_device_manufacturer, 
"bezel description" as bezel_description ,
"reporting app name" as reporting_app_name ,
 "product name" as product_name   
from trouble_panels tp inner join s3_external_schema.panel_telemetry pt on tp.panel_serial_number=pt."panel serial number" where year = 2025
and month = 3);

DROP MODEL IF EXISTS trouble_panels_config_only_model;
CREATE MODEL trouble_panels_config_only_model
FROM  (select  left(panel_serial_number,4) as panel_prefix,event_count,app_build_number,app_release,app_version,
 os ,os_version,platform_name,platform_version, 
 usb_device_manufacturer,bezel_description ,reporting_app_name,product_name  from trouble_panels_ml_mdm_config_train)
 TARGET hieventcountlikely
 FUNCTION trouble_prediction_function_config_only
 IAM_ROLE  'arn:aws:iam::487651640582:role/dbadmin_policy'
 MODEL_TYPE LINEAR_LEARNER
 PROBLEM_TYPE BINARY_CLASSIFICATION
 OBJECTIVE 'F1'
 SETTINGS (
      S3_BUCKET 'redshift-ml-temp-no-pii',
      S3_GARBAGE_COLLECT ON 
    );
