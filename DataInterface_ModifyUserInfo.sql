SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO



if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DataInterface_ModifyUserInfo]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[DataInterface_ModifyUserInfo]
GO


--=====================================================================
-- Procedure: DataInterface_ModifyUserInfo
-- Purpose: Change Password or Email or both.
-- Input: 
--		1. @UserId int
--		2. @Email varchar(100) (optional)
--		3. @Password varchar(50) (optional)

-- Usage: EXEC DataInterface_ModifyUserInfo @UserId = 12345, @Password = 'abcde'
--     OR EXEC DataInterface_ModifyUserInfo @UserId = 12345, @Email = 'abc@abc.com'
--     OR EXEC DataInterface_ModifyUserInfo @UserId = 12345, 
--                               @Password = 'abcde', 
--                               @Email = 'abc@abc.com'
-- Modified: Guocheng Jin 08/19/2004, check the Login_Name & Inst_ID as the PrimaryKey
--	     William Ying 08/16/2005, Added Cust_ID
--	     William Ying 10/31/2005, Added RRN per Stephen Fedor's request.  Bug #19041
--           Greeshma Neglur 09/26/2006, Added SubExpireDate, EncryptPwd and Middle initial as parameters
--			                 Commented out Not NULL check for Address1,Address2,City,State,Zip as
--					 they are required to be deleted when NULL
--	     Greeshma Neglur 10/12/2006 - allow user to set NewModuleID = NULL
--
-- Note: Be very carefull when use this stored procedure.
-- Modify: 04/23/2006: Christine Fang - doesn't allow updating the Modules2 directly. Need to update the NewModuleID
--                                      then the SP will update the Modules2 based on the NewModuleID
-- Modify: 11/20/2006: Jingsong Ou. -- Change @lDPhone from varchar(10) to varchar(20) to fix bug for saving 
--                                      phone number like '303-779-0987'
-- Modify: 09/25/2007: Xiao Tan       - Add code to insert any new Inst_ID, GroupID combination to AM_SolutionID
-- Modify: 03/04/2008: Jing He	 -- Add code to update StandaloneFeatureID
-- Modify: 04/24/2008: Sunil Negi	-This SP expects the Password parameter to contain the encrypted password.
-- Modify: 05/14/2008: Jing He		-- Remove Password parameter and bring EncryptPWD parameter forward
-- Modify: 12/09/2008: Ke Cheng    --- remove StandaloneFeatureID
-- Modify: 02/24/2009: Jing He		-- update PasswordCreateDate if EncryptPWD is updated
-- Modify: 03/12/2009: Jing He		-- prevent updating the group id of a super user with empty group
-- Modify: 05/26/2009: Jing He		-- prevent overwritting when any of the following fields is left blank: NewModuleID, Address1, Address2, City, State, Zip
-- Modify: 09/18/2009: Jing He		-- allow same login name or email exist in same Inst_ID but different GroupID
-- Modify: 3/15/10. Dawn Xiao, Dawn Xiao, can not modify super user here(e.g. can not use administrator+accessUserID as @Login)      
-- bf 7/11 use EncryptPWDTDES column with is now 128 TDES needs more space
-- Modify: 10/31/2012  Max Ma       -- remove EncryptedPWD
--
--============================================================
 
 
CREATE     PROCEDURE [dbo].[DataInterface_ModifyUserInfo]
	@UserId int = null,
	@Email varchar(100) = NULL,
	-- @Password varchar(50) = NULL,
	--@Modules2 int = null,
	@NewModuleID varchar(10) = NULL,
	--@StandaloneFeatureID varchar(10) = NULL,
        @GroupId varchar(10) = '',
	@LoginName varchar(64) = NULL,
	@FName Varchar(30) = NULL,
        @Middle_Init char(1) = null,
	@LName varchar(30) = NULL,
	@CompanyName Varchar(50) = NULL,
	@Address1 Varchar(50) = NULL,
	@Address2 Varchar(50) = NULL,
	@City Varchar(30) = NULL,
	@State Varchar(20) = NULL,
	@Zip Varchar(10) = NULL,
	@Country Varchar(20) = NULL,
	@DPhone	varchar(20) = NULL,
	@Cust_ID int = NULL,
 	@RegisteredRepNumber     varchar(20) = null,
        @SubExpireDate datetime = null,
        
	
	@msg varchar(100) OUTPUT
AS

	SET NOCOUNT ON

	DECLARE @err int, @rcnt int, @lEmail varchar(100)--, @lPassword varchar(50)
	DECLARE @lLoginName varchar(64), @lFName varchar(30), @lLName varchar(30)
	DECLARE @lCompanyName varchar(50), @lAddress1 varchar(50), @lAddress2 varchar(50)
	DECLARE @lCity varchar(30), @lState varchar(20), @lZip varchar(10)
	DECLARE @lCountry varchar(20), @lDPhone varchar(20)
	DECLARE @Inst_ID varchar(20)
	DECLARE @Modules2 INT
	DECLARE @Password varchar(50)
	--SET @Password = NULL

	SET @lEmail = lower(ltrim(rtrim(@Email)))
	--SET @lPassword = ltrim(rtrim(@Password))
	SET @lLoginName = ltrim(rtrim(@LoginName))
	SET @lFName = ltrim(rtrim(@FName))
	SET @lLName  = ltrim(rtrim(@LName ))
	SET @lCompanyName = ltrim(rtrim(@CompanyName))
	SET @lAddress1 = ltrim(rtrim(@Address1))
	SET @lAddress2 = ltrim(rtrim(@Address2))
	SET @lCity = ltrim(rtrim(@City))
	SET @lState = ltrim(rtrim(@State))
	SET @lZip = ltrim(rtrim(@Zip))
	SET @lCountry = ltrim(rtrim(@Country))
	SET @lDPhone = ltrim(rtrim(@DPhone))
	SET @NewModuleID =  ltrim(rtrim(@NewModuleID))
	--SET @StandaloneFeatureID = ltrim(rtrim(@StandaloneFeatureID))
	 if  @UserId is null or @UserId < 0  
	 begin  
	 	 raiserror('Please provide User ID.',16,1)  
	 	 return -1  
	 end 

	if not exists (select 1 from SSM_User_Login where User_ID = @UserId)
	begin
	 	 raiserror('User not exist.',16,1)  
	 	 return -1  
	end

	if @GroupId is null or len(@GroupId)=0
	begin
		--set @GroupId = ''
		select @GroupId = GroupId from SSM_User_Login where User_ID = @UserId
	end

	IF( @NewModuleID IS NOT NULL) AND ( NOT EXISTS (SELECT * FROM SSMModuleFeatures WHERE NewModuleID = @NewModuleID))
	BEGIN
	  RAISERROR('The NewModuleID (SolutionID) is NOT valid.',16,1)      
	  RETURN -1      


	END

--IF( @StandaloneFeatureID IS NOT NULL) AND (len(@StandaloneFeatureID) >0 ) AND ( NOT EXISTS (SELECT * FROM SSMStandaloneModuleFeatures WHERE StandaloneFeatureID = @StandaloneFeatureID))
--	BEGIN
--	  RAISERROR('The StandaloneFeatureID is NOT valid.',16,1)      
--	  RETURN -1      
--	END

	select @Inst_ID = Inst_ID from SSM_User_Login 
	WHERE User_ID = @UserId

	if @LoginName like 'administrator%' or @lLoginName like 'administrator%'        
	begin      
	  raiserror('you can not modify super user here.',16,1)                
	  return -1  
	end

	if exists(select * from SSM_User_Login where Login_Name = @LoginName and Inst_ID = @Inst_ID and User_ID <> @UserId and GroupId = @GroupId)      
	 begin      
	  raiserror('A user with the same login, same inst_id and same GroupId already exists.',16,1)      
	  return -1      
	 end    

	if exists(select * from SSM_User_Login where Email = @lEmail and Inst_ID = @Inst_ID and User_ID <> @UserId and GroupId = @GroupId)      
	 begin      
	  raiserror('A user with the same Email, same inst_id and same GroupId already exists.',16,1)      
	  return -1      
	 end     

	IF len(@GroupId)>0 AND exists (SELECT 1 FROM SSM_User_Login WHERE SuperUser = 1 AND GroupId = '' AND User_ID = @UserId)
	begin      
	  raiserror('Cannot update the group id of a super user with empty group.',16,1)      
	  return -1      
	end  

	SELECT @err = 0, @rcnt = 0

	-- Email Update
	IF @lEmail IS NOT NULL
	begin
		UPDATE SSM_User_Login
		SET Email = @lEmail
		WHERE User_ID = @UserId
		
		UPDATE SSM_User_Profile
		SET Email = @lEmail
		WHERE User_ID = @UserId
	end

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- Password Update
	--IF @lPassword IS NOT NULL
	--	UPDATE SSM_User_Login
	--	SET Password = @lPassword
		--WHERE User_ID = @UserId

	--SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- Login name Update
	IF @lLoginName IS NOT NULL
		UPDATE SSM_User_Login
		SET Login_Name = @lLoginName
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount


	-- Modules2 Update
	/*IF @Modules2 IS NOT NULL AND @Modules2 > 0
		UPDATE SSM_User_Login
		SET Modules2 = @Modules2
		WHERE User_ID = @UserId
	*/
	
	-- NewModuleID update
	IF @NewModuleID IS NOT NULL AND LEN(@NewModuleID) > 0
	BEGIN

		SELECT @Modules2 = ModuleValue FROM SSMModuleFeatures WHERE NewModuleID = @NewModuleID
		
		UPDATE SSM_User_Login
		SET NewModuleID = @NewModuleID, Modules2 = @Modules2
		WHERE User_ID = @UserId

	END
-- removed per ticket# 57774
	--ELSE
	-- GN - 10/12/2006 - allow user to set NewModuleID = NULL
	--BEGIN
	--	UPDATE SSM_User_Login
	--	SET NewModuleID = @NewModuleID, Modules2 = NULL
	--	WHERE User_ID = @UserId
	--END

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- StandaloneFeatureID update
	--IF @StandaloneFeatureID IS NOT NULL AND LEN(@StandaloneFeatureID) > 0
	--BEGIN

	--	UPDATE SSM_User_Login
	--	SET StandaloneFeatureID = @StandaloneFeatureID
	--	WHERE User_ID = @UserId

	--END
	--ELSE
	--BEGIN
	--	UPDATE SSM_User_Login
	--	SET StandaloneFeatureID = NULL
	--	WHERE User_ID = @UserId
	--END

	--SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- First Name Update
	IF @lFName IS NOT NULL
		UPDATE SSM_User_Profile
		SET First_Name = @lFName
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

        -- Middle Initial Update
	IF @Middle_Init IS NOT NULL
		UPDATE SSM_User_Profile
		SET Middle_Init = @Middle_Init
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- Last Name Update
	IF @lLName IS NOT NULL
		UPDATE SSM_User_Profile
		SET Last_Name = @lLName
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount


	-- Company Name Update
	IF @lCompanyName IS NOT NULL
		UPDATE SSM_User_Profile
		SET CompanyName = @lCompanyName
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- Address1 Update
	IF @lAddress1 IS NOT NULL
		UPDATE SSM_User_Profile
		SET Address_1 = @lAddress1
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount


	-- Address2 Update
	IF @lAddress2 IS NOT NULL
		UPDATE SSM_User_Profile
		SET Address_2 = @lAddress2
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount


	-- City Update
	IF @lCity IS NOT NULL
		UPDATE SSM_User_Profile
		SET City = @lCity
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- State Update
	IF @lState IS NOT NULL
		UPDATE SSM_User_Profile
		SET State = @lState
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- Zip Update
	IF @lZip IS NOT NULL
		UPDATE SSM_User_Profile
		SET ZipCode = @lZip
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- Country Update
	IF @lCountry IS NOT NULL
		UPDATE SSM_User_Profile
		SET Country = @lCountry
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- Daytime phone Update
	IF @lDPhone IS NOT NULL
		UPDATE SSM_User_Profile
		SET Dphone = @lDPhone
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount


	-- GroupId update 
	IF len(@GroupId) > 0	
		UPDATE SSM_User_Login
		SET GroupId = @GroupId
		WHERE User_ID = @UserId		

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-------------
	--- added by xiao tan on 9/25/2007
	-------------

	IF len(@GroupId) > 0 and not exists (
		select 	1 
		from 	dbo.AM_SolutionID
		where 	InstId = @Inst_ID 
			and 
			GroupId = @GroupId
	)
	insert 	dbo.AM_SolutionID
		(InstId, GroupId, Status, Comments)
	select
		@Inst_ID, @GroupId, 1, 'inserted from Data Interface'
	
	------
	--- end of 9/25/2007 change
	------
	
        


	-- Cust_ID update 
	IF @Cust_ID IS NOT NULL
		UPDATE SSM_User_Profile
		SET Cust_ID = @Cust_ID
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- RRN update 
	IF @RegisteredRepNumber IS NOT NULL
		UPDATE SSM_User_Login
		SET RegisteredRepNumber = ltrim(rtrim(@RegisteredRepNumber))
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

        -- SubExpireDate update 
	IF @SubExpireDate IS NOT NULL
		UPDATE SSM_User_Login
		SET SubExpireDate = ltrim(rtrim(@SubExpireDate))
		WHERE User_ID = @UserId

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount

	-- SELECT @err = @err + @@error, @rcnt = @rcnt + @@rowcount


	IF @err = 0 AND @rcnt <> 0
	BEGIN
		Set @msg =  'The update is succsessful!'
		Return 0
	END
	ELSE IF @err = 0 AND @rcnt = 0 
		BEGIN
			  --PRINT 'There are no such user in the database'
			 raiserror( 'There are no such user in the database',16,1)  
	 		 return -1  
		END
		  ELSE 
		BEGIN
			--PRINT 'The file transfer is NOT succsessful! There are errors!'
			 raiserror ('The update is NOT succsessful! There are errors!',16,1)  
	 	 	return -1  
		END


set nocount off

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

grant exec on DataInterface_ModifyUserInfo to rl_Advisor
