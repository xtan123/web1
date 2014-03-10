
USE Advtools
GO
go

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT * FROM dbo.sysobjects	WHERE id = OBJECT_ID(N'dbo.[adminSaveDirectRptIntegration_V2]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[adminSaveDirectRptIntegration_V2]
GO

  
-- ==============================================================================================    
-- Name:   adminSaveDirectRptIntegration_V2
--  
-- Purpose:  save direct report integration configured in the presentation studio
--  
-- Location:  Advtools  
-- Authorized to: rl_Advisor    
-- Parameter:    
-- Input		@InstId VARCHAR(6),
--				@UserId int, 
--				@TemplateIds VARCHAR(400),
--				@MenuDiscs VARCHAR(1500), 
--				@UnivsForReport varchar(max),
--				@MenuIds varchar(400),
--				@CultureId varchar(15) = 'en-US'
--       
-- Output		
--    
-- Result Set: 
--    
-- Return:   none    
-- Exception values:  none    
  
-- Created By:  Zhijian Liu  
-- Created On:  11/06/2013  
  
-- Modifien By:	Max Ma  
-- Modifien On:	1/17/2014
--				added @UserId int
--   
-- Description:   
--  
-- Example:
/* 
	EXEC Advtools.[dbo].[adminGettMenuIdsByTemplates] '12335|23234|55567|123455', 'first report|foesse|Moring Issue|Equity Detail'
	
	EXEC Advtools.[dbo].[adminSaveDirectRptIntegration] 'ADMIN9', '12335|23234|55567', 'first report|foesse|reret', 'USAFO;USAOF|CANFO;CANFE|USAST;USAFE;USAVA', '266|265|269'
	EXEC Advtools.[dbo].[adminSaveDirectRptIntegration] 'ADMIN9', '12335|55567|123455', 'first report|Moring Issue|Equity Detail', 'CANFO;CANFE|USAST;USAFE;USAVA|USAFO', '267|269|273'
	SELECT * FROM [dbo].[MenuStructure]
	SELECT * FROM [dbo].[DirectReportIntegration] WHERE InstId = 'ADMIN9'
	SELECT * FROM [MultiLanguageNames]  where ItemType = 'MUN' and InstId = 'ADMIN9'
*/   
  
-- ==================================================================================  
  
CREATE PROCEDURE [dbo].[adminSaveDirectRptIntegration_V2] 
 @InstId VARCHAR(6), 
 @UserId int,
 @TemplateIds VARCHAR(400),
 @TempTypelateIds VARCHAR(400),
 @MenuDiscs VARCHAR(1500), 
 @UnivsForReport varchar(max),
 @MenuIds varchar(400),
 @CultureId varchar(15) = 'en-US'
AS  
  SET NOCOUNT ON  
  
    DECLARE @ErrorMessage NVARCHAR(200)
    
	CREATE TABLE #Template (seqOrder int, templateId int, templateName varchar(30), univ varchar(200), mnuDisplayId varchar(20), menuId int, templateTypeId int)  
	INSERT #Template  
	SELECT a.SplitOrder, CAST(a.SplitData AS int), b.SplitData, c.SplitData, 'mnu' + a.SplitData + '_' + e.SplitData, CAST(d.SplitData AS INT), CAST(e.SplitData AS INT)
	FROM dbo.splitWithOrder(@TemplateIds, '|') a, 
		 dbo.splitWithOrder(@MenuDiscs, '|') b, 
		 dbo.splitWithOrder(@UnivsForReport, '|') c,
		 dbo.splitWithOrder(@MenuIds, '|') d,
		 dbo.splitWithOrder(@TempTypelateIds, '|') e

	WHERE a.SplitOrder = b.SplitOrder AND c.SplitOrder = d.SplitOrder AND b.SplitOrder = c.SplitOrder AND e.SplitOrder = d.SplitOrder

	DECLARE @MenuIdList varchar(100)
	SET @MenuIdList = ''
	DECLARE @TemplateList varchar(100)
	SET @TemplateList = ''
	DECLARE @TemplateTypeList varchar(100)
	SET @TemplateTypeList = ''
		
	SELECT @MenuIdList = @MenuIdList + CONVERT (VARCHAR (20), mnu.MenuId) + ',', 
			@TemplateList = @TemplateList + CONVERT (VARCHAR (20), tem.templateId) + ',',
			@TemplateTypeList = @TemplateTypeList + CONVERT (VARCHAR (20), tem.templateTypeId) + ','
	FROM #Template tem INNER JOIN [dbo].[MenuStructure] mnu
	ON tem.menuId = mnu.MenuId AND tem.mnuDisplayId <> mnu.DisplayId
	
	IF LEN(@MenuIdList) > 0
	BEGIN
		SET @MenuIdList = LEFT(@MenuIdList, LEN(@MenuIdList)-1)
		SET @TemplateList = LEFT(@TemplateList, LEN(@TemplateList)-1)
		SET @TemplateTypeList = LEFT(@TemplateTypeList, LEN(@TemplateTypeList)-1)

		SET @ErrorMessage = 'One or more menus (' + @MenuIdList + ') connected to the different direct report template and template type.'    
		GOTO OnError 	
	END
	
	DELETE [dbo].[DirectReportIntegration] WHERE InstId = @InstId and @UserId = IsNull(UserId, -1)
	
	INSERT INTO [dbo].[DirectReportIntegration] (InstId, UserId, TemplateId, TemplateTypeId, RptDescription, UnivsForReport)  
	SELECT @InstId, @UserId, templateId, templateTypeId, templateName, univ 
	FROM #Template 

	UPDATE [dbo].[MultiLanguageNames] 
	SET ItemName = tem.templateName 
	FROM [dbo].[MultiLanguageNames] mlt INNER JOIN #Template  tem
	ON mlt.ItemId = tem.menuId
	WHERE mlt.InstId = @InstId AND mlt.ItemType = 'MUN' AND CultureId = @CultureId
	
	DELETE #Template WHERE menuId in 
	(
		SELECT ItemId 
		FROM [dbo].[MultiLanguageNames] mlt 
		INNER JOIN #Template  tem
		ON mlt.ItemId = tem.menuId
		WHERE mlt.InstId = @InstId AND mlt.ItemType = 'MUN' AND CultureId = @CultureId
	) 

	INSERT INTO [dbo].[MultiLanguageNames] (ItemId, ItemType, CultureId, ItemName, InstId) 
	SELECT menuId,'MUN', @CultureId, templateName, @InstId 
	FROM #Template
 
	DROP TABLE #Template
	
	RETURN 0
 
	OnError:    
		RAISERROR(@ErrorMessage, 17, 1)    
		---ROLLBACK TRANSACTION    
		RETURN @@ERROR   
		
  SET NOCOUNT OFF  
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE ON [dbo].[adminSaveDirectRptIntegration_V2]  TO [rl_Advisor]
GO
