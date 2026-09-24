USE [MosaiqAdmin]
GO

/****** Object:  StoredProcedure [dbo].[sp_Visits_Databook_Totals]    Script Date: 9/24/2026 2:20:20 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE procedure [dbo].[sp_Visits_Databook_Totals]
AS

BEGIN
-- RUN AFTER sp_Visits_Databook --

/*************** DECLARE & SET the @fiscal_year varible to the 4-digit fiscal year value ****************/
          /************ UPDATE THE TABLE NAME in the SELECT statement after FROM ************/
   ------------------ highlight and execute the declaration plus all of the 1st query ------------------- 
DECLARE @fiscal_year as smallint;
SET @fiscal_year = 1111;   --reset this variable to the 4-digit fiscal year

---1st QUERY---
-- drop table #data
SELECT FY
      ,case 
		when DataBook_Category = 'Machine Only Procedure' then 'RO Machine'
		when databook_category = 'Clinic Procedure' then 'Clinic Procedures' --changing this for uniform insertion into Visits_Databook_Published_Metrics_2014_[fiscal year]_LOCKED
	    else DataBook_Category
	   end DataBook_Category
      ,visit_bucket
      ,is_billable_professional_visit
      ,is_TeleMed
      ,is_NewPatient
      ,appt_dt
      ,pat_id1
      ,pat_mrn
      ,prov_key_MQ
      ,prov_NPI_IDX
      ,sch_id
      ,sch_set_id
      ,[vis.Seq_Group]
      ,Seq_Pat_Appts_Per_Day_by_Group
      ,in_Bernalillo
      ,in_state
      ,pat_city
      ,pat_county
      ,pat_postal
      ,Lock_dtTm  -- This is set in sp_visits_databook as the run date of that process
into #data
  FROM dbo.Visits_Databook_dtls_fiscal_year_LOCKED  --Update table name to be the detail table's name
  where fy = @fiscal_year
    --and appt_dt < 'yyyymmdd'  --add this for preliminary data


--the #data and dbo.Visits_Databook_dtls_[fiscal_year]_LOCKED tables should have the same number of rows
select count(*) from #data
select count(*) from dbo.Visits_Databook_dtls_fiscal_year_LOCKED 
 
--Data check: select * from #data where pat_county = '?' - research any of these and correct as necessary

/*************** HIGHLIGHT AND EXECUTE THE 2nd QUERY ****************/
---2nd QUERY---
-- DIVIDE THE NM RESIDENTS UP BY COUNTY
-- drop table #pats_by_county
select pat_county, count(pat_id1) as pats_by_county
into #pats_by_county
from (
       select distinct pat_id1,
	          pat_county, 
	          in_bernalillo,
	          in_state
         from #data
        where in_state = 'Y'
     ) as A 
group by pat_county 

--select * from #pats_by_county order by pat_county  --This data will go into the FY[2-digit fiscal year] County Map Data.xlsx spreadsheet.

/*************** HIGHLIGHT AND EXECUTE THE 3rd QUERY ****************/
---3rd QUERY---
-- drop table #pats_out_of_state
select count(pat_id1) as pats_out_of_state
into #pats_out_of_state
from (
       select distinct pat_id1
         from #data
        where in_state = 'N'
     ) as A 

--select * from #pats_out_of_state                  --This value will go into the FY[2-digit fiscal year] County Map Data.xlsx spreadsheet.

/*************** HIGHLIGHT AND EXECUTE THE 4th QUERY ****************/
---4th QUERY---
-- drop table #total_unique_pats
select sum(A.ttl_pats) tot_unq_pats
into #total_unique_pats
from
(
   select sum(pats_by_county) as ttl_pats
     from #pats_by_county
   union
   select pats_out_of_state as ttl_pats
     from #pats_out_of_state
) A

--select * from #total_unique_pats

/*************** HIGHLIGHT AND EXECUTE THE 5th QUERY ****************/
---5th QUERY---
-- drop table #encs_by_cat
select FY, databook_category, count(sch_set_id) as encs_by_category
into #encs_by_cat
from #data 
group by FY, databook_category

--select * from #encs_by_cat

/************** as reported to Rae Ann Paden and Marlena *****************/

/*************** DECLARE & SET the @fy varible to the 4-digit fiscal year value ****************/
 --------------- highlight and execute the declaration plus all of the 6th query --------------

DECLARE @fyr as smallint;
SET @fyr = '1111';   --reset this variable to the 4-digit fiscal year

---6th QUERY---
-- drop table #reportableData
select * 
into #reportableData
from (
select fy, 'Visits' as Metric, 'Total Clinic Encounters' as Category, count(*) as value  -- number of records in #data; same number inserted into Visits_Databook_Published_Metrics_2014_2021_LOCKED
from #data
group by fy
UNION
select fy, 'Visits' as Metric, databook_category, count(sch_set_id) as value  -- total number of each: RO Machine, Clinic Porcedures, and Infusion visits
from #data
where databook_category in ('Infusion', 'RO Machine', 'Clinic Procedures')
group by fy, databook_category
UNION
select @fyr as fy, 'Unique Patients' as Metric, 'Bernco' as category, Pats_by_county as value  -- total number of Bernalillo county residents
from #pats_by_county
where pat_county = 'Bernalillo'
UNION
select @fyr as fy, 'Unique Patients' as Metric, 'NM Outside Bernco' as category,  SUM(pats_by_county) as value -- total number of NM residents outside of Bernalillo county
from #pats_by_county
where pat_county <> 'Bernalillo'
UNION
select @fyr as fy, 'Unique Patients' as Metric, 'Out-of_State' as category,  Pats_Out_of_State as value  --total number of out-of-state patients
from #pats_out_of_state 
UNION
select @fyr as fy, 'Unique Patients' as Metric, 'NM' as category, SUM(pats_by_county) as  value   --total number of NM residents in all counties
from #pats_by_county
UNION
select @fyr as fy, 'Unique Patients' as Metric, 'All' as category,  tot_unq_pats as value  --total of all unique patients both in and out-of-state
from #total_unique_pats
UNION
select fy, 'Visits' as Metric, DataBook_Category, encs_by_category as value --total Physician & PFSS - Billable visits
from #encs_by_cat
where databook_category in ('Physicians & PFSS - Billable')
UNION
select fy, 'Visits' as Metric, DataBook_Category, encs_by_category as value --total Physician & PFSS - Non-Billable visits
from #encs_by_cat
where databook_category in ('Physicians & PFSS - Non-Billable')
UNION
select fy, 'Visits' as Metric, DataBook_Category, encs_by_category as value --total Shot Clinic visits
from #encs_by_cat
where databook_category in ('Shot Clinic')
UNION
select fy, 'Visits' as Metric, DataBook_Category, encs_by_category as value --total Medical Support visits ='s Nurses, Psych Interns, Protocol Nurses/Staff
from #encs_by_cat
where databook_category in ('Medical Support') 
UNION
select fy, 'Visits' as Metric, 'All Other Categories', sum(encs_by_category) as value 
from #encs_by_cat
where databook_category in ('Physicians & PFSS - Billable','Physicians & PFSS - Non-Billable','Shot Clinic','Medical Support') 
group by fy
) as A            --This data will go into the Visits_Databook_Published_Metrics_2014_[current fiscal year]_LOCKED table and the FY[2-digit fiscal year] Data Book.xlsx spreadsheet.

--select * from #reportableData order by FY, Metric, category

--INSERT SUMMARY DATA INTO the Visits_Databook_Published_Metrics_2014_[4-digit fiscal year]_LOCKED table; inserts 8 lines--

/***************** RENAME THE Visits_Databook_Published_Metrics_2014_[PREVIOUS fiscal year]_LOCKED TABLE TO ****************/
                            -- Visits_Databook_Published_Metrics_2014_[CURRENT fiscal year]_LOCKED -- 

               /*************** DECLARE & SET the @fy varible to FY + the 2-digit fiscal year ****************/
                       /************* CHANGE THE TABLE NAME IN THE INSERT INTO LINE TO ***************/
					       -- Visits_Databook_Published_Metrics_2014_[CURRENT fiscal year]_LOCKED --
				               
 ---------- highlight and execute the declaration plus INSERT INTO/SELECT statement ---------

DECLARE @fy as varchar(4)
SET @fy = 'FY11'  --reset this variable to FY + the 2-digit fiscal year

INSERT INTO Visits_Databook_Published_Metrics_2014_current_fiscal_year_LOCKED (fy,metric,category,Value,run_date) 
SELECT @fy 
      ,metric
	  ,category
	  ,value
	  ,GETDATE() as run_date
 FROM #reportableData
where metric in ('Unique Patients','Visits')
  and category in ('All','Bernco','NM','NM Outside Bernco','Clinic Procedures','Infusion','RO Machine','Total Clinic Encounters')

--select * from dbo.Visits_Databook_Published_Metrics_2014_[current fiscal year]_LOCKED
--order by fy, metric, category


 
END
GO


