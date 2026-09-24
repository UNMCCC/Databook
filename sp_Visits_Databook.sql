USE [MosaiqAdmin]
GO

/****** Object:  StoredProcedure [dbo].[sp_Visits_Databook]    Script Date: 9/24/2026 1:58:45 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_Visits_Databook]
AS

BEGIN
-- UOP & DATABOOK:	Data Book must be locked same day as UOP data.  
--
/************************ CREATE the details table *********************/
--DO NOT DELETE THE LOCKED DETAIL TABLE AFTER THE NUMBERS 
-- HAVE BEEN SUPPLIED TO MARLENA OR RAE ANN PADEN
---PRIOR TO DELIVERY, YOU CAN DELETE AND RECREATE THE TABLE AS NEEDED---

--replace 'fiscal_year' in the table name on the line below with 
-- the 4-digit fiscal year

--if you are providing preliminary data and want to freeze that, 
-- rename the table something like 
-- Visits_Databook_dtls_[fiscal_year]_Prelim__LOCKED

CREATE TABLE Visits_Databook_dtls_fiscal_year_LOCKED(
	[FY] [varchar](4) NOT NULL,
	[DataBook_Category] [varchar](40) NOT NULL,
	[visit_bucket] [varchar](40) NOT NULL,
	[is_billable_professional_visit] [varchar](1) NULL,
	[is_TeleMed] [varchar](1) NULL,
	[is_NewPatient] [varchar](1) NULL,
	[appt_dt] [varchar](8) NULL,
	[pat_id1] [int] NULL,
	[pat_mrn] [varchar](20) NULL,
	[prov_key_MQ] [int] NULL,
	[prov_NPI_IDX] [varchar](20) NULL,
	[sch_id] [int] NULL,
	[sch_set_id] [int] NULL,
	[vis.Seq_Group] [varchar](60) NULL,
	[Seq_Pat_Appts_Per_Day_by_Group] [int] NULL,
	[in_Bernalillo] [varchar](1) NULL,
	[in_state] [varchar](1) NULL,
	[pat_city] [varchar](80) NULL,
	[pat_county] [varchar](50) NULL,
	[pat_postal] [varchar](50) NULL,
	[Lock_dtTm] [datetime] NULL
) ON [PRIMARY]

/** DECLARE & SET the @fiscal_year varible to the 4-digit fiscal year value */
-- highlight and execute the declaration plus all of the 1st query - 

DECLARE @fiscal_year as smallint;
SET @fiscal_year = 1111;   --reset this variable to the correct 4-digit fiscal year

---1st QUERY---
-- IDENTIFY STATE FOR COUNTY MAP

if object_id('tempdb..#pats') is not null
    drop table #pats

select DISTINCT 
	vis.pat_id1, 
	vis.pat_mrn,
	case 
		when adm.pat_state = 'NM' 
		then adm.pat_city
		else ' '
	end pat_city,
	case 
		when adm.pat_state = 'NM' 
		then left(pat_postal,5)
		else pat_postal
	end pat_postal,
	case
		when (adm.pat_state <> 'NM' or pat_postal = '85131')  --'or' added to deal with a FY22 out-of-state patient whose pat_city is Albuquerque, but pat_postal is AZ
		then 'Out-of-State' 
		else adm.pat_state
	end pat_state
into #pats
FROM MosaiqAdmin.dbo.Visits_in_Buckets vis
left join MosaiqAdmin.dbo.RefStaging_Admin adm on vis.pat_id1 = adm.pat_id1
WHERE FY in (@fiscal_year) 
--and appt_dt < 'yyyymmdd'  --add this for preliminary data


/*************** HIGHLIGHT AND EXECUTE THE 2nd QUERY ****************/
---2nd QUERY---
-- GET COUNTY USING MG DSS BY ZIP (not all zips are in there - to correct, some are hardcoded)

if object_id('tempdb..#Pats_County') is not null
	drop table #pats_county

SELECT
	pat_id1,
	CASE WHEN pat_state = 'NM' then 'Y' else 'N' end in_state,
	CASE WHEN pat_state = 'NM' and pat_county = 'BERNALILLO' then 'Y' else 'N' end in_Bernalillo,
	pat_city,
	pat_county,
	pat_postal	
INTO #pats_county
from (
	select distinct
		pat_id1,
		pat_mrn,
		isNull(pat_postal, 'unknown') as pat_postal,
		isNull(pat_state, 'unknown') as pat_state,
		CASE 
			WHEN #pats.pat_state = 'NM'
				THEN
				CASE
					when pat_postal = '87033' then 'SANDOVAL'
					when pat_postal = '87555' then 'TAOS'
					when pat_postal =  '87547' then 'LOS ALAMOS' 
					else isNull(z.zip_county, 'unknown')
				END
			ELSE isNull(z.zip_county, 'Out-of-state')
		end pat_county,
		isNull(pat_city, 'unknown') as pat_city
	from #pats
	left join [uh-datawarehouse].unmmgdss.dss.zip_dim z on #Pats.pat_postal = convert(varchar,z.zip_key)	--changed to left join bc we were missing some people
) as A

--the #pats and #pat_county temp tables should have the same number of rows
select count(*) from #pats
select count(*) from #pats_county

/** DECLARE & SET the @fisc_year varible to the 4-digit fiscal year value ***/
----- highlight and execute the declaration plus all of the 3rd query 
DECLARE @fisc_year as smallint;
SET @fisc_year = 1111; --reset this variable to the correct 4-digit fiscal year

---3rd QUERY---
-- drop table #data

if object_id('tempdb..#data') is not null
    drop table #data

select 
	vis.fy,
	case 
		when vis.Visit_bucket in ('Physician/APP', 'PFSS') and is_billable_professional_visit = 'Y'  -- these 2 can be yes or no
		then 'Physicians & PFSS - Billable'
		when vis.Visit_bucket in ('Physician/APP', 'PFSS') and is_billable_professional_visit = 'N' 
		then 'Physicians & PFSS - Non-Billable'
		else vis.visit_bucket
	end databook_category,
	vis.visit_bucket,
	vis.is_billable_professional_visit,
	vis.is_TeleMed,
	case
		when actv_code_desc = 'New Patient'
		then 'Y'
		else 'N'
	end is_NewPatient,
	vis.appt_dt,	
	vis.pat_id1,
	vis.pat_mrn,
	prov_key_MQ,
	vis.prov_NPI_IDX,
	vis.sch_id,
	vis.sch_set_id,
	vis.Seq_Group,
	vis.Seq_Pat_Appts_Per_Day_by_Group,
	#pats_County.in_Bernalillo,
	#pats_County.in_state,
	#pats_County.pat_city,
	#pats_County.pat_county,
	#pats_County.pat_postal,
	GetDate() as Lock_DtTm
into #data
FROM MosaiqAdmin.dbo.Visits_in_Buckets vis
left join #pats_County on vis.pat_id1 = #pats_county.pat_id1
where vis.visit_bucket in ('Clinic Procedure', 'Infusion', 'Machine Only Procedure',  'Medical Support', 'Physician/APP', 'PFSS', 'Shot Clinic')
and vis.Seq_Pat_Appts_Per_Day_by_Group = 1  -- patient with multiple appts with same provider in same day will count as 1 visit; patient with multiple appts scheduled to RO machines in same day will count as 1 visit
and vis.fy in (@fisc_year)
--and appt_dt < 'yyyymmdd'  --add this for preliminary data

/**** LOAD THE DETAIL DATA FROM #data INTO THE LOCKED FISCAL YEAR TABLE CREATED ABOVE *****/
-- rename the table being inserted into to the same name as the table created in 
-- this stored procedure's 1st step --
-- highlight and execute the INSERT INTO/SELECT statement
INSERT INTO dbo.Visits_Databook_dtls_fiscal_year_LOCKED  
SELECT * from #data

--the #data and dbo.Visits_Databook_dtls_[fiscal_year]_LOCKED tables should have the same number of rows
select count(*) from #data
select count(*) from dbo.Visits_Databook_dtls_fiscal_year_LOCKED


/*************** DO NOT EXECUTE THE STORED PROCEDURE ****************/
/*** Close the query window so that the table name and fiscal year variable values are not retained ***/

END