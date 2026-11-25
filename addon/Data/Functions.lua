-- claude-in-wow: the game's functions that only read, the only ones Claude
-- may have called (Reads.lua). Made from Blizzard's documentation of WoW
-- Forever by the plugin's tools\functions.mjs: not to be edited by hand.

local addonName, ns = ...

ns.FUNCTIONS = {
    [""] = [[
        AreClassRolesSoftSuggestions AreDangerousScriptsAllowed CanBeRaidTarget CanChangePlayerDifficulty CanDualWield CanEjectPassengerFromSeat CanInspect
        CanLootUnit CanMapChangeDifficulty CanMerchantRepair CanPortGraveyard CanShowResetInstances CanShowSetRoleButton CanSwitchVehicleSeat
        CanUpgradeToCurrentExpansion DoesCurrentLocaleSellExpansionLevels GetAchievementCriteriaInfo GetAchievementInfo GetAchievementNumCriteria
        GetActionCooldown GetActionCount GetActionInfo GetActionText GetAddOnCPUUsage GetAddOnMemoryUsage GetAllowLowLevelRaid GetAllowRecentAlliesSeeLocation
        GetAreaSpiritHealerTime GetAreaText GetArmorPenetration GetAttackPowerForStat GetAuctionItemInfo GetAutoDeclineGuildInvites
        GetAutoDeclineNeighborhoodInvites GetAvailableBandwidth GetAvailableLocaleInfo GetAvailableLocales GetAverageItemLevel GetAvoidance
        GetBackgroundLoadingStatus GetBaseDifficultyID GetBattlefieldStatus GetBillingTimeRested GetBindLocation GetBinding GetBindingKey GetBlockChance
        GetBuildInfo GetBuildOption GetCallstackHeight GetCameraFOVDefaults GetCategoryInfo GetCategoryList GetCategoryNumAchievements GetCemeteryPreference
        GetClassicExpansionLevel GetClientDisplayExpansionLevel GetCollapsingStarCost GetCombatRating GetCombatRatingBonus
        GetCombatRatingBonusForCombatRatingValue GetComboPoints GetCorpseRecoveryDelay GetCorruption GetCorruptionResistance GetCreditsDisplayInfo
        GetCritChance GetCritChanceFromStat GetCritChanceProvidesParryEffect GetCurrentCinematicSummary GetCurrentEventID GetCurrentRegion
        GetCurrentRegionName GetCurrentTitle GetCursorCenterPosition GetCursorDelta GetCursorInfo GetCursorMoney GetCursorPosition
        GetDefaultAbbreviationBreakpoints GetDefaultScale GetDifficultyInfo GetDodgeChance GetDodgeChanceFromAttribute GetDownloadedPercentage
        GetDungeonDifficultyID GetErrorCallstackHeight GetEventCPUUsage GetEventTime GetEvictionTimeRemaining GetExpansionDisplayInfo GetExpansionForLevel
        GetExpansionLevel GetExpansionTrialInfo GetExpertise GetExpertisePercent GetFactionInfo GetFileIDFromPath GetFileStreamingStatus GetFontInfo GetFonts
        GetForbiddenObjectTable GetFrameCPUUsage GetFramerate GetFunctionCPUUsage GetGameMessageInfo GetGameTime GetGlancingBlowChance GetGlancingBlowPenalty
        GetGossipText GetGuildInfo GetGuildRosterLastOnline GetHaste GetHealthRegen GetHealthRegenFromSpirit GetHitModifier GetInboxHeaderInfo GetInboxItem
        GetInboxNumItems GetInstanceBootTimeRemaining GetInstanceInfo GetInstanceLockTimeRemaining GetInstanceLockTimeRemainingEncounter
        GetInventoryItemCooldown GetInventoryItemDurability GetInventoryItemID GetInventoryItemLink GetInventoryItemQuality GetInventorySlotInfo GetItemGem
        GetJailersTowerLevel GetLFGDungeonInfo GetLFGQueueStats GetLatestCompletedAchievements GetLatestThreeSenders GetLegacyRaidDifficultyID GetLifesteal
        GetLocalGameTime GetLocale GetLootMethod GetLootSlotInfo GetLootSlotLink GetLootSpecialization GetMacroInfo GetManaRegen GetManaRegenFromSpirit
        GetMastery GetMasteryEffect GetMaxLevelForExpansionLevel GetMaxLevelForLatestExpansion GetMaxLevelForPlayerExpansion GetMaxPlayerLevel
        GetMaximumExpansionLevel GetMeleeHaste GetMerchantItemLink GetMerchantItemMaxStack GetMerchantNumItems GetMinimapZoneText GetMinimumExpansionLevel
        GetMirrorTimerInfo GetMirrorTimerProgress GetModResilienceDamageReduction GetMoney GetMouseButtonClicked GetMouseButtonName GetMouseFoci
        GetMovieDownloadProgress GetNativeRealmID GetNegativeCorruptionEffectInfo GetNetIpTypes GetNetStats GetNextAvailableRaidTargetMarkerIndex
        GetNormalizedRealmName GetNumAuctionItems GetNumBindings GetNumBuybackItems GetNumDeclensionSets GetNumExpansions GetNumFactions GetNumGroupMembers
        GetNumGuildMembers GetNumLootItems GetNumMacros GetNumQuestChoices GetNumQuestRewards GetNumSavedInstances GetNumShapeshiftForms GetNumSkillLines
        GetNumSubgroupMembers GetNumTalentTabs GetNumTalents GetNumTitles GetNumTotemSlots GetNumTrainerServices GetNumWhoResults GetOSLocale GetObjectiveText
        GetOffhandHitModifier GetOverrideAPBySpellPower GetOverrideSpellPowerByAP GetPVPDesired GetPVPGearStatRules GetPVPLifetimeStats GetPVPRankInfo
        GetPVPRankProgress GetPVPSessionStats GetPVPTimer GetPVPYesterdayStats GetParryChance GetParryChanceFromAttribute GetPartyAssignment GetPetActionInfo
        GetPetCritChance GetPetDodgeChance GetPetExperience GetPetHappiness GetPetHitChanceModifier GetPetMeleeHaste GetPetSpellBonusDamage
        GetPetSpellHitChanceModifier GetPhysicalScreenSize GetPlayerFacing GetPlayerInfoByGUID GetPowerRegen GetPowerRegenForPowerType GetProgressText
        GetProtocolTypes GetPvpPowerDamage GetPvpPowerHealing GetQuestID GetQuestItemInfo GetQuestText GetRaidDifficultyID GetRaidRosterInfo
        GetRaidTargetIndex GetRangedAttackPowerForStat GetRangedCritChance GetRangedHaste GetRangedHitModifier GetRealZoneText GetRealmID GetRealmName
        GetReleaseTimeRemaining GetRepairAllCost GetResSicknessDuration GetRestState GetRewardMoney GetRewardText GetRewardXP GetRuneCooldown GetRuneCount
        GetSavedInstanceEncounterInfo GetSavedInstanceInfo GetScreenDPIScale GetScreenHeight GetScreenWidth GetScriptBucketThrottleLimits GetScriptCPUUsage
        GetSecondsUntilParentalControlsKick GetServerExpansionLevel GetServerTime GetShapeshiftForm GetShapeshiftFormInfo GetSheathState GetShieldBlock
        GetSkillLineInfo GetSourceLocation GetSpecializationInfoForClassID GetSpecializationInfoForSpecID GetSpecializationNameForSpecID
        GetSpecializationSystem GetSpeed GetSpellBonusDamage GetSpellBonusHealing GetSpellCritChance GetSpellCritChanceFromStat GetSpellHitModifier
        GetSpellPenetration GetStatistic GetStringFromModifiers GetSturdiness GetSubZoneText GetTalentInfo GetTalentTabInfo GetTaxiBenchmarkMode
        GetThreatStatusColor GetTickTime GetTime GetTimePreciseSec GetTitleName GetTitleText GetTotalAchievementPoints GetTotemCannotDismiss GetTotemDuration
        GetTotemInfo GetTotemTimeLeft GetTrainerServiceCost GetTrainerServiceDescription GetTrainerServiceInfo GetTrainerServiceLevelReq
        GetTrainerServiceSkillReq GetUICameraInfo GetUnitChargedPowerPoints GetUnitEmpowerHoldAtMaxTime GetUnitEmpowerMinHoldTime GetUnitEmpowerStageDuration
        GetUnitHealthModifier GetUnitMaxHealthModifier GetUnitPowerBarInfo GetUnitPowerBarInfoByID GetUnitPowerBarStrings GetUnitPowerBarStringsByID
        GetUnitPowerBarTextureInfo GetUnitPowerBarTextureInfoByID GetUnitPowerModifier GetUnitSpeed GetUnitTotalModifiedMaxHealthPercent
        GetUnspentTalentPoints GetUpgradeExpansionLevel GetVehicleUIIndicator GetVehicleUIIndicatorSeat GetVersatilityBonus GetWeaponEnchantInfo
        GetXPExhaustion GetZoneText HasAPEffectsSpellPower HasAction HasDualWieldPenalty HasFullControl HasIgnoreDualWieldWeapon HasKey HasLootSpecializations
        HasNewMail HasNoReleaseAura HasPetUI HasSPEffectsAttackPower Is64BitClient IsAdvancedFlyableArea IsAltKeyDown IsBetaBuild IsCemeterySelectionAvailable
        IsCharacterNewlyBoosted IsCollisionEnabled IsControlKeyDown IsCpuBound IsCursorVisible IsDebugBuild IsDemonHunterAvailable IsDrivableArea
        IsDualWielding IsEuropeanNumbers IsExpansionTrial IsFalling IsFlyableArea IsFlying IsGuildLeader IsInGroup IsInGuild IsInInstance IsInJailersTower
        IsInRaid IsIndoors IsInsane IsItemPreferredArmorType IsJailersTowerLayerTimeLocked IsKeyDown IsLeftAltKeyDown IsLeftControlKeyDown IsLeftMetaKeyDown
        IsLeftShiftKeyDown IsLegacyDifficulty IsLinuxClient IsLoggedIn IsMacClient IsMetaKeyDown IsModifierKeyDown IsMounted IsMouseButtonDown IsMovieLocal
        IsMoviePlayable IsMovieReadable IsOnGroundFloorInJailersTower IsOnTournamentRealm IsOutOfBounds IsOutdoors IsPVPTimerRunning IsPlayerInGuildFromGUID
        IsPlayerInWorld IsPlayerMoving IsPublicBuild IsPublicTestClient IsRaidMarkerActive IsRaidMarkerSystemEnabled IsRangedWeapon IsResting
        IsRightAltKeyDown IsRightControlKeyDown IsRightMetaKeyDown IsRightShiftKeyDown IsShiftKeyDown IsStealthed IsSubmerged IsSwimming IsTargetLoose
        IsTestBuild IsThreatWarningEnabled IsTitleKnown IsUnitModelReadyForUI IsUsableAction IsUsingFixedTimeStep IsUsingGamepad IsUsingMouse IsWindowsClient
        IsXPUserDisabled NumTaxiNodes PlayerCanTeleport PlayerGetTimerunningSeasonID PlayerIsInCombat PlayerIsPVPInactive PlayerIsSpellTarget
        PlayerIsTimerunning ShouldDisplayRaidRolesInSocialFrame ShouldDisplayStoryModeTooltipInSocialFrame ShouldShowExpansionUpgradeBanner
        ShouldShowIslandsWeeklyPOI ShouldShowSpecialSplashScreen TaxiNodeCost TaxiNodeGetType TaxiNodeName UnitAffectingCombat UnitAlliedRaceInfo UnitArmor
        UnitAttackPower UnitAttackSpeed UnitBattlePetLevel UnitBattlePetSpeciesID UnitBattlePetType UnitCanAssist UnitCanAttack UnitCanCooperate
        UnitCanPetBattle UnitCastingDuration UnitCastingInfo UnitChannelDuration UnitChannelInfo UnitChromieTimeID UnitClass UnitClassBase UnitClassFromGUID
        UnitClassification UnitControllingVehicle UnitCreatureFamily UnitCreatureID UnitCreatureType UnitDamage UnitDefense UnitDefenseSkill
        UnitDetailedThreatSituation UnitDistanceSquared UnitEffectiveLevel UnitEmpoweredChannelDuration UnitEmpoweredStageDurations
        UnitEmpoweredStagePercentages UnitExists UnitFactionGroup UnitFullName UnitGUID UnitGetAvailableRoles UnitGetDetailedHealPrediction
        UnitGetIncomingHeals UnitGetTotalAbsorbs UnitGetTotalHealAbsorbs UnitGroupRolesAssigned UnitGroupRolesAssignedEnum UnitHPPerStamina
        UnitHasEffectivelyTankAura UnitHasLootInteraction UnitHasMouseoverHighlight UnitHasPowerType UnitHasRelicSlot UnitHasVehiclePlayerFrameUI
        UnitHasVehicleUI UnitHealth UnitHealthMax UnitHealthMissing UnitHealthPercent UnitHonor UnitHonorLevel UnitHonorMax UnitInAnyGroup UnitInBattleground
        UnitInOtherParty UnitInParty UnitInPartyIsAI UnitInPartyShard UnitInRaid UnitInRange UnitInSubgroup UnitInVehicle UnitInVehicleControlSeat
        UnitInVehicleHidesPetFrame UnitIsAFK UnitIsBattlePet UnitIsBattlePetCompanion UnitIsBossMob UnitIsCharmed UnitIsConnected UnitIsControlling
        UnitIsCorpse UnitIsDND UnitIsDead UnitIsDeadOrGhost UnitIsEnemy UnitIsFeignDeath UnitIsFriend UnitIsGameObject UnitIsGhost UnitIsGroupAssistant
        UnitIsGroupLeader UnitIsHumanPlayer UnitIsInInteractRange UnitIsInMyGuild UnitIsInteractable UnitIsLieutenant UnitIsMercenary UnitIsMinion
        UnitIsNPCAsPlayer UnitIsOtherPlayersBattlePet UnitIsOtherPlayersPet UnitIsOwnerOrControllerOfUnit UnitIsPVP UnitIsPVPFreeForAll UnitIsPVPSanctuary
        UnitIsPlayer UnitIsPlayerControlledOrGroupMember UnitIsPossessed UnitIsQuestBoss UnitIsRaidOfficer UnitIsSameServer UnitIsTapDenied UnitIsTrivial
        UnitIsUnconscious UnitIsUnit UnitIsVisible UnitIsWildBattlePet UnitLeadsAnyGroup UnitLevel UnitName UnitNameFromGUID UnitNameUnmodified
        UnitNameplateShowsWidgetsOnly UnitNumPowerBarTimers UnitOnTaxi UnitOwnerGUID UnitPVPName UnitPVPRank UnitPartialPower UnitPercentHealthFromGUID
        UnitPhaseReason UnitPlayerControlled UnitPlayerOrPetInParty UnitPlayerOrPetInRaid UnitPosition UnitPower UnitPowerBarID UnitPowerBarTimerInfo
        UnitPowerDisplayMod UnitPowerMax UnitPowerMissing UnitPowerPercent UnitPowerType UnitPvpClassification UnitQuestTrivialLevelRange
        UnitQuestTrivialLevelRangeScaling UnitRace UnitRangedAttackPower UnitRangedDamage UnitReaction UnitRealmRelationship UnitResistance UnitSelectionColor
        UnitSelectionType UnitSex UnitSexBase UnitShouldDisplayName UnitShouldDisplaySpellTargetName UnitSpellHaste UnitSpellTargetClass UnitSpellTargetName
        UnitStagger UnitStat UnitTargetsVehicleInRaidUI UnitThreatLeadSituation UnitThreatPercentageOfLead UnitThreatSituation UnitTokenFromGUID
        UnitTreatAsPlayerForDisplay UnitTrialBankedLevels UnitTrialXP UnitUsesAmmo UnitUsingVehicle UnitVehicleSeatCount UnitVehicleSeatInfo UnitVehicleSkin
        UnitWeaponAttackPower UnitWidgetSet UnitXP UnitXPMax
    ]],
    ["C_AchievementInfo"] = [[
        AreGuildAchievementsEnabled GetRewardItemID GetSupercedingAchievements IsGuildAchievement IsValidAchievement
    ]],
    ["C_ActionBar"] = [[
        FindAssistedCombatActionButtons FindFlyoutActionButtons FindPetActionButtons FindSpellActionButtons GetActionAutocast GetActionBarPage
        GetActionChargeDuration GetActionCharges GetActionCooldown GetActionCooldownDuration GetActionDisplayCount GetActionLossOfControlCooldownDuration
        GetActionLossOfControlCooldownInfo GetActionText GetActionTexture GetActionUseCount GetBonusBarIndex GetBonusBarIndexForSlot GetBonusBarOffset
        GetExtraBarIndex GetItemActionOnEquipSpellID GetMultiCastBarIndex GetOverrideBarIndex GetOverrideBarSkin GetPetActionPetBarIndices
        GetProfessionQuality GetProfessionQualityInfo GetSpell GetTempShapeshiftBarIndex GetVehicleBarIndex HasAction HasAssistedCombatActionButtons
        HasBonusActionBar HasExtraActionBar HasFlyoutActionButtons HasOverrideActionBar HasPetActionButtons HasPetActionPetBarIndices HasRangeRequirements
        HasSpellActionButtons HasTempShapeshiftActionBar HasVehicleActionBar IsActionInRange IsAssistedCombatAction IsAttackAction IsAutoCastPetAction
        IsAutoRepeatAction IsConsumableAction IsCurrentAction IsEnabledAutoCastPetAction IsEquippedAction IsEquippedGearOutfitAction IsHarmfulAction
        IsHelpfulAction IsHighestSpellRank IsInterruptAction IsItemAction IsMacroActionWithShowTooltip IsOnBarOrSpecialBar IsPossessBarVisible
        IsStackableAction IsUsableAction ShouldOverrideBarShowHealthBar ShouldOverrideBarShowManaBar ShouldShowKeyring
    ]],
    ["C_AddOns"] = [[
        DoesAddOnExist DoesAddOnHaveLoadError GetAddOnDependencies GetAddOnEnableState GetAddOnInfo GetAddOnInterfaceVersion GetAddOnLocalTable
        GetAddOnMetadata GetAddOnName GetAddOnNotes GetAddOnOptionalDependencies GetAddOnSecurity GetAddOnTitle GetNumAddOns GetScriptsDisallowedForBeta
        IsAddOnDefaultEnabled IsAddOnLoadOnDemand IsAddOnLoadable IsAddOnLoaded IsAddonVersionCheckEnabled
    ]],
    ["C_AdventureMap"] = [[
        GetAdventureMapTextureKit GetNumMapInsets GetNumQuestOffers GetNumZoneChoices GetQuestPortraitInfo
    ]],
    ["C_AlliedRaces"] = [[
        GetAllRacialAbilitiesFromID GetRaceInfoByID
    ]],
    ["C_AnimaDiversion"] = [[
        GetAnimaDiversionNodes GetOriginPosition GetReinforceProgress GetTextureKit
    ]],
    ["C_ArdenwealdGardening"] = [[
        GetGardenData IsGardenAccessible
    ]],
    ["C_AreaPoiInfo"] = [[
        GetAreaPOIForMap GetAreaPOIInfo GetAreaPOISecondsLeft GetDelvesForMap GetDragonridingRacesForMap GetEventsForMap GetQuestHubsForMap IsAreaPOITimed
    ]],
    ["C_ArtifactUI"] = [[
        CanApplyArtifactRelic CanApplyCursorRelicToSlot CanApplyRelicItemIDToEquippedArtifactSlot CanApplyRelicItemIDToSlot
        DoesEquippedArtifactHaveAnyRelicsSlotted GetAppearanceInfo GetAppearanceInfoByID GetAppearanceSetInfo GetArtifactArtInfo GetArtifactInfo
        GetArtifactItemID GetArtifactTier GetArtifactXPRewardTargetInfo GetCostForPointAtRank GetEquippedArtifactArtInfo GetEquippedArtifactInfo
        GetEquippedArtifactItemID GetEquippedArtifactNumRelicSlots GetEquippedArtifactRelicInfo GetEquippedRelicLockedReason GetForgeRotation
        GetItemLevelIncreaseProvidedByRelic GetMetaPowerInfo GetNumAppearanceSets GetNumObtainedArtifacts GetNumRelicSlots GetPointsRemaining
        GetPowerHyperlink GetPowerInfo GetPowerLinks GetPowers GetPowersAffectedByRelic GetPowersAffectedByRelicItemLink GetPreviewAppearance GetRelicInfo
        GetRelicInfoByItemID GetRelicLockedReason GetRelicSlotType GetRespecArtifactArtInfo GetRespecArtifactInfo GetRespecCost GetTotalPowerCost
        GetTotalPurchasedRanks IsArtifactDisabled IsArtifactItem IsAtForge IsEquippedArtifactDisabled IsEquippedArtifactMaxed IsMaxedByRulesOrEffect
        IsPowerKnown IsViewedArtifactEquipped ShouldSuppressForgeRotation
    ]],
    ["C_AssistedCombat"] = [[
        GetActionSpell GetNextCastSpell GetRotationSpells IsAvailable
    ]],
    ["C_AuctionHouse"] = [[
        CanCancelAuction GetAuctionInfoByID GetAuctionItemSubClasses GetAvailablePostCount GetBidInfo GetBidType GetBids GetBrowseResults GetCancelCost
        GetCommoditySearchResultInfo GetCommoditySearchResultsQuantity GetExtraBrowseInfo GetFilterGroups GetItemCommodityStatus GetItemKeyFromItem
        GetItemKeyInfo GetItemKeyRequiredLevel GetItemKeySampleLink GetItemSearchResultInfo GetItemSearchResultsQuantity GetMaxBidItemBid GetMaxBidItemBuyout
        GetMaxCommoditySearchResultPrice GetMaxItemSearchResultBid GetMaxItemSearchResultBuyout GetMaxOwnedAuctionBid GetMaxOwnedAuctionBuyout GetNumBidTypes
        GetNumBids GetNumCommoditySearchResults GetNumItemSearchResults GetNumOwnedAuctionTypes GetNumOwnedAuctions GetNumReplicateItems GetOwnedAuctionInfo
        GetOwnedAuctionType GetOwnedAuctions GetQuoteDurationRemaining GetReplicateItemBattlePetInfo GetReplicateItemInfo GetReplicateItemLink
        GetReplicateItemTimeLeft GetTimeLeftBandInfo HasFavorites HasFullBidResults HasFullBrowseResults HasFullCommoditySearchResults
        HasFullItemSearchResults HasFullOwnedAuctionResults HasMaxFavorites HasSearchResults IsFavoriteItem IsSellItemValid IsThrottledMessageSystemReady
        ShouldAutoPopulatePrice
    ]],
    ["C_AutoComplete"] = [[
        GetAutoCompletePresenceID GetAutoCompleteRealms GetAutoCompleteResults IsRecognizedName
    ]],
    ["C_AzeriteEmpoweredItem"] = [[
        CanSelectPower GetAllTierInfo GetAllTierInfoByItemID GetAzeriteEmpoweredItemRespecCost GetPowerInfo GetPowerText GetSpecsForPower
        HasAnyUnselectedPowers HasBeenViewed IsAzeriteEmpoweredItem IsAzeriteEmpoweredItemByID IsAzeritePreviewSourceDisplayable IsHeartOfAzerothEquipped
        IsPowerAvailableForSpec IsPowerSelected
    ]],
    ["C_AzeriteEssence"] = [[
        CanActivateEssence CanDeactivateEssence CanOpenUI GetEssenceHyperlink GetEssenceInfo GetEssences GetMilestoneEssence GetMilestoneInfo
        GetMilestoneSpell GetMilestones GetNumUnlockedEssences GetNumUsableEssences GetPendingActivationEssence HasNeverActivatedAnyEssences
        HasPendingActivationEssence IsAtForge
    ]],
    ["C_AzeriteItem"] = [[
        FindActiveAzeriteItem GetAzeriteItemXPInfo GetPowerLevel GetUnlimitedPowerLevel HasActiveAzeriteItem IsAzeriteItem IsAzeriteItemAtMaxLevel
        IsAzeriteItemByID IsAzeriteItemEnabled IsUnlimitedLevelingUnlocked
    ]],
    ["C_Bank"] = [[
        AreAnyBankTypesViewable CanDepositMoney CanPurchaseBankTab CanUseBank CanViewBank CanWithdrawMoney DoesBankTypeSupportAutoDeposit
        DoesBankTypeSupportMoneyTransfer HasMaxBankTabs IsItemAllowedInBankType ShouldUsePlayerBagsInBank
    ]],
    ["C_BlizzCon2026"] = [[
        GetExperience IsActive IsColdSwapFeatureEnabled
    ]],
    ["C_CVar"] = [[
        AreCVarsLoaded GetCVar GetCVarBool
    ]],
    ["C_Calendar"] = [[
        AreNamesReady CanAddEvent CanSendInvite GetClubCalendarEvents GetDayEvent GetDefaultGuildFilter GetEventIndex GetEventIndexInfo GetEventInfo
        GetFirstPendingInvite GetGuildEventInfo GetGuildEventSelectionInfo GetHolidayInfo GetMaxCreateDate GetMinDate GetMonthInfo GetNextClubId
        GetNumDayEvents GetNumGuildEvents GetNumInvites GetNumPendingInvites GetRaidInfo IsActionPending IsEventOpen
    ]],
    ["C_CampaignInfo"] = [[
        GetAvailableCampaigns GetCampaignChapterInfo GetCampaignID GetCampaignInfo GetChapterIDs GetCurrentChapterID GetFailureReason GetState IsCampaignQuest
    ]],
    ["C_ChallengeMode"] = [[
        CanUseKeystoneInCurrentMap GetActiveChallengeMapID GetActiveKeystoneInfo GetAffixInfo GetChallengeCompletionInfo GetDeathCount
        GetDungeonScoreRarityColor GetGuildLeaders GetKeystoneLevelRarityColor GetLeaverPenaltyWarningTimeLeft GetMapScoreInfo GetMapTable GetMapUIInfo
        GetOverallDungeonScore GetPowerLevelDamageHealthMod GetSlottedKeystoneInfo GetSpecificDungeonOverallScoreRarityColor
        GetSpecificDungeonScoreRarityColor GetStartTime HasSlottedKeystone IsChallengeModeActive IsChallengeModeResettable
    ]],
    ["C_ChatBubbles"] = [[
        GetAllChatBubbles
    ]],
    ["C_ChatInfo"] = [[
        AreOutgoingAddonChatMessagesRestricted CanPlayerSpeakLanguage GetChannelInfoFromIdentifier GetChannelRosterInfo GetChannelRuleset
        GetChannelRulesetForChannelID GetChannelShortcut GetChannelShortcutForChannelID GetChatTypeName GetClubStreamIDs GetColorForChatType
        GetGeneralChannelID GetGeneralChannelLocalID GetMentorChannelID GetNumActiveChannels GetNumReservedChatWindows GetRegisteredAddonMessagePrefixes
        IsAddonMessagePrefixRegistered IsChannelRegional IsChannelRegionalForChannelID IsLoggingChat IsLoggingCombat IsPartyChannelType
        IsRegionalServiceAvailable IsTimerunningPlayer IsValidCombatFilterName
    ]],
    ["C_ChromieTime"] = [[
        GetChromieTimeExpansionOption GetChromieTimeExpansionOptions
    ]],
    ["C_CinematicList"] = [[
        GetUICinematicList
    ]],
    ["C_ClassColor"] = [[
        GetClassColor
    ]],
    ["C_ClassTalents"] = [[
        CanChangeTalents CanCreateNewConfig CanEditTalents GetActiveConfigID GetActiveHeroTalentSpec GetConfigIDsBySpecID GetHasStarterBuild
        GetHeroTalentSpecsForClassSpec GetLastSelectedSavedConfigID GetNextStarterBuildPurchase GetStarterBuildActive GetTraitTreeForSpec
        HasUnspentHeroTalentPoints HasUnspentTalentPoints IsConfigPopulated
    ]],
    ["C_ClickBindings"] = [[
        CanSpellBeClickBound GetBindingType GetEffectiveInteractionButton GetProfileInfo GetTutorialShown
    ]],
    ["C_Club"] = [[
        AreMembersReady CanResolvePlayerLocationFromClubMessageData DoesAnyCommunityHaveUnreadMessages DoesCommunityHaveMembersOfTheOppositeFaction
        GetAssignableRoles GetAvatarIdList GetClubCapacity GetClubInfo GetClubLimits GetClubMembers GetClubPrivileges GetClubStreamNotificationSettings
        GetCommunityNameResultText GetGuildClubId GetInvitationCandidates GetInvitationInfo GetInvitationsForClub GetInvitationsForSelf GetMemberInfo
        GetMemberInfoForSelf GetMessagesInRange GetStreamInfo GetStreamViewMarker GetStreams GetSubscribedClubs GetTickets IsAccountMuted IsBeginningOfStream
        IsEnabled IsRestricted IsSubscribedToStream ShouldAllowClubType
    ]],
    ["C_ClubFinder"] = [[
        DoesPlayerBelongToClubFromClubGUID GetClubFinderDisableReason GetClubRecruitmentSettings GetClubTypeFromFinderGUID GetFocusIndexFromFlag
        GetPlayerApplicantLocaleFlags GetPlayerApplicantSettings GetPlayerClubApplicationStatus GetPlayerSettingsFocusFlagsSelectedCount
        GetPostingIDFromClubFinderGUID GetRecruitingClubInfoFromClubID GetRecruitingClubInfoFromFinderGUID GetStatusOfPostingFromClubId
        GetTotalMatchingCommunityListSize GetTotalMatchingGuildListSize HasAlreadyAppliedToLinkedPosting HasPostingBeenDelisted IsCommunityFinderEnabled
        IsEnabled IsListingEnabledFromFlags IsPostingBanned IsValidSearchString PlayerGetClubInvitationList ShouldShowClubFinder
    ]],
    ["C_ColorOverrides"] = [[
        GetColorForQuality GetColorOverrideInfo GetDefaultColorForQuality
    ]],
    ["C_CombatAudioAlert"] = [[
        GetCategoryVoice GetCategoryVolume GetFormatSetting GetSpeakerSpeed GetSpecSetting GetThrottle IsEnabled
    ]],
    ["C_CombatLog"] = [[
        AreFilteredEventsEnabled DoesObjectMatchFilter GetEntryRetentionTime GetMessageLimit IsCombatLogRestricted
    ]],
    ["C_CombatLogInternal"] = [[
        GetCurrentEventInfo
    ]],
    ["C_CombatText"] = [[
        GetActiveUnit GetCurrentEventInfo
    ]],
    ["C_Container"] = [[
        GetBackpackAutosortDisabled GetBackpackSellJunkDisabled GetBagName GetBagSlotFlag GetBankAutosortDisabled GetContainerFreeSlots
        GetContainerItemCooldown GetContainerItemDurability GetContainerItemEquipmentSetInfo GetContainerItemID GetContainerItemInfo GetContainerItemLink
        GetContainerItemPurchaseCurrency GetContainerItemPurchaseInfo GetContainerItemPurchaseItem GetContainerItemQuestInfo GetContainerNumFreeSlots
        GetContainerNumSlots GetInsertItemsLeftToRight GetItemCooldown GetMaxArenaCurrency GetSortBagsRightToLeft HasContainerItem IsBattlePayItem
        IsContainerFiltered PlayerHasHearthstone
    ]],
    ["C_ContentTracking"] = [[
        GetBestMapForTrackable GetCollectableSourceTrackingEnabled GetCollectableSourceTypes GetCurrentTrackingTarget GetEncounterTrackingInfo
        GetNextWaypointForTrackable GetObjectiveText GetTitle GetTrackablesOnMap GetTrackedIDs GetVendorTrackingInfo GetWaypointText IsNavigable IsTrackable
        IsTracking
    ]],
    ["C_ContributionCollector"] = [[
        GetActive GetAtlases GetBuffs GetContributionAppearance GetContributionCollectorsForMap GetContributionResult GetDescription
        GetManagedContributionsForCreatureID GetName GetOrderIndex GetRequiredContributionCurrency GetRequiredContributionItem GetRewardQuestID GetState
        HasPendingContribution IsAwaitingRewardQuestData
    ]],
    ["C_CooldownViewer"] = [[
        GetCooldownViewerCategorySet GetCooldownViewerCooldownInfo GetGroupBuffItems GetLayoutData GetValidAlertTypes IsCooldownViewerAvailable
    ]],
    ["C_CovenantCallings"] = [[
        AreCallingsUnlocked
    ]],
    ["C_CovenantPreview"] = [[
        GetCovenantInfoForPlayerChoiceResponseID
    ]],
    ["C_CovenantSanctumUI"] = [[
        CanAccessReservoir CanDepositAnima GetAnimaInfo GetCurrentTalentTreeID GetFeatures GetRenownLevel GetRenownLevels GetRenownRewardsForLevel
        GetSanctumType GetSoulCurrencies HasMaximumRenown IsPlayerInRenownCatchUpMode IsWeeklyRenownCapped
    ]],
    ["C_Covenants"] = [[
        GetActiveCovenantID GetCovenantData GetCovenantIDs
    ]],
    ["C_CraftingOrders"] = [[
        AreOrderNotesDisabled CanOrderSkillAbility GetClaimedOrder GetCrafterBuckets GetCrafterOrders GetCraftingOrderTime GetCustomerCategories
        GetCustomerOptions GetCustomerOrders GetDefaultOrdersSkillLine GetMyOrders GetNumFavoriteCustomerOptions GetOrderClaimInfo GetPersonalOrdersInfo
        HasFavoriteCustomerOptions IsCustomerOptionFavorited ShouldShowCraftingOrderTab
    ]],
    ["C_CreatureInfo"] = [[
        GetClassInfo GetCreatureFamilyIDs GetCreatureFamilyInfo GetCreatureID GetCreatureTypeIDs GetCreatureTypeInfo GetFactionInfo GetRaceInfo
    ]],
    ["C_CurrencyInfo"] = [[
        CanTransferCurrency DoesCurrentFilterRequireAccountCurrencyData DoesWarModeBonusApply GetAzeriteCurrencyID GetBackpackCurrencyInfo
        GetBasicCurrencyInfo GetCoinIcon GetCoinText GetCoinTextureString GetCostToTransferCurrency GetCurrencyContainerInfo GetCurrencyDescription
        GetCurrencyFilter GetCurrencyIDFromLink GetCurrencyInfo GetCurrencyInfoFromLink GetCurrencyLink GetCurrencyListInfo GetCurrencyListLink
        GetCurrencyListSize GetDragonIslesSuppliesCurrencyID GetFactionGrantedByCurrency GetMaxTransferableAmountFromQuantity GetPlayerCurrencyCategoryInfo
        GetWarResourcesCurrencyID IsAccountCharacterCurrencyDataReady IsAccountTransferableCurrency IsAccountWideCurrency IsCurrencyContainer
        IsCurrencyTransferInProgress IsCurrencyTransferTransactionDataReady PlayerHasMaxQuantity PlayerHasMaxWeeklyQuantity
    ]],
    ["C_Cursor"] = [[
        GetCursorItem
    ]],
    ["C_DamageMeter"] = [[
        GetAvailableCombatSessions GetCombatSessionFromID GetCombatSessionFromType GetCombatSessionSourceFromID GetCombatSessionSourceFromType
        GetSessionDurationSeconds IsDamageMeterAvailable
    ]],
    ["C_DateAndTime"] = [[
        GetCalendarTimeFromEpoch GetCurrentCalendarTime GetSecondsUntilDailyReset GetSecondsUntilWeeklyReset GetServerTimeLocal GetWeeklyResetStartTime
        IsDayTime
    ]],
    ["C_DeathInfo"] = [[
        GetCorpseMapPosition GetDeathReleasePosition GetGraveyardsForMap GetSelfResurrectOptions
    ]],
    ["C_DeathRecap"] = [[
        GetRecapEvents GetRecapLink GetRecapMaxHealth HasRecapEvents
    ]],
    ["C_DelvesUI"] = [[
        GetActiveDelveTier GetCompanionInfoForActivePlayer GetCreatureDisplayInfoForCompanion GetCurioLink GetCurioNodeForCompanion
        GetCurioRarityByTraitCondAccountElementID GetCurrentDelvesSeasonNumber GetDelveEntranceBackgroundWidgetSetID GetDelveEntranceDescriptionString
        GetDelveEntranceHeaderString GetDelveEntranceMapID GetDelveEntranceTiers GetDelveEntranceTitleString GetDelvesAffixSpellsForSeason
        GetDelvesFactionForSeason GetDelvesMinRequiredLevel GetFactionForCompanion GetFlavorNodeForCompanion GetFlavorNodeNameForCompanion
        GetLockedTextForCompanion GetModelSceneForCompanion GetPlayerCompanionPDEID GetRoleNodeForCompanion GetRoleSubtreeForCompanion
        GetTieredEntranceOptionalAffixTraitTreeID GetTieredEntrancePDEID GetTieredEntranceType GetTraitTreeForCompanion GetUnseenCuriosBySlotType
        GetWorldTierDifficultyForActivePlayer HasActiveDelve HasActiveLFGLair HasActiveLair IsDelveEntranceTierEnabled IsEligibleForActiveDelveRewards
        IsInLair IsTraitTreeForCompanion
    ]],
    ["C_DyeColor"] = [[
        GetAllDyeColorCategories GetAllDyeColors GetDyeColorCategoryInfo GetDyeColorInfo GetDyeColorsForItem GetDyeColorsForItemLocation
        GetDyeColorsInCategory IsDyeColorOwned
    ]],
    ["C_EditMode"] = [[
        GetAccountSettings GetEditModeDefaultLayout GetLayouts IsValidLayoutName
    ]],
    ["C_EncounterEvents"] = [[
        GetEventColor GetEventInfo GetEventList GetEventSound HasEventInfo
    ]],
    ["C_EncounterJournal"] = [[
        GetBaseDifficultyID GetDungeonEntrancesForMap GetEncounterJournalLink GetEncountersOnMap GetInstanceForGameMap GetLootInfo GetLootInfoByIndex
        GetSectionIconFlags GetSectionInfo GetSlotFilter IsEncounterComplete
    ]],
    ["C_EncounterTimeline"] = [[
        GetCurrentTime GetEventColor GetEventCountBySource GetEventHighlightTime GetEventInfo GetEventList GetEventState GetEventTimeElapsed
        GetEventTimeRemaining GetEventTimer GetEventTrack GetSortedEventList GetTrackInfo GetTrackList GetTrackMaxEventDuration GetTrackType GetViewType
        HasActiveEvents HasAnyEvents HasPausedEvents HasVisibleEvents IsEventBlocked IsFeatureAvailable IsFeatureEnabled
    ]],
    ["C_EncounterWarnings"] = [[
        GetColorForSeverity GetEditModeWarningInfo GetPlayCustomSoundsWhenHidden GetSoundKitForSeverity GetWarningsShown IsFeatureAvailable IsFeatureEnabled
    ]],
    ["C_EndOfMatchUI"] = [[
        GetEndOfMatchDetails
    ]],
    ["C_EquipmentSet"] = [[
        CanUseEquipmentSets GetEquipmentSetAssignedSpec GetEquipmentSetForSpec GetEquipmentSetID GetEquipmentSetIDs GetEquipmentSetInfo GetIgnoredSlots
        GetItemIDs GetItemLocations GetNumEquipmentSets IsSlotIgnoredForSave
    ]],
    ["C_EventScheduler"] = [[
        CanShowEvents GetActiveContinentName GetEventUiMapID GetEventZoneName GetOngoingEvents GetScheduledEvents HasData HasSavedReminders
    ]],
    ["C_EventToastManager"] = [[
        GetLevelUpDisplayToastsFromLevel GetNextToastToDisplay
    ]],
    ["C_EventUtils"] = [[
        IsCallbackEvent IsEventValid
    ]],
    ["C_Flyout"] = [[
        GetFlyoutID GetFlyoutInfo GetFlyoutSlotInfo GetFlyoutTexture GetNumFlyouts
    ]],
    ["C_FogOfWar"] = [[
        GetFogOfWarForMap GetFogOfWarInfo
    ]],
    ["C_FriendList"] = [[
        GetFriendInfo GetFriendInfoByIndex GetIgnoreName GetNumFriends GetNumIgnores GetNumOnlineFriends GetNumWhoResults GetSelectedFriend GetSelectedIgnore
        GetWhoInfo GetWhoRaceFilters IsFriend IsIgnored IsIgnoredByGuid IsLegacyFriendSystemEnabled IsOnIgnoredList
    ]],
    ["C_GamePad"] = [[
        GetActiveDeviceID GetAllConfigIDs GetAllDeviceIDs GetAllowHoverEventsWithFreeLook GetCombinedDeviceID GetConfig GetDeviceMappedState GetDeviceRawState
        GetLedColor GetPowerLevel IsEnabled
    ]],
    ["C_GamepadUI"] = [[
        GetFirstGamepadActionBarStorageSlotIndexForActiveStance GetFirstGamepadActionStorageSlotIndex GetFirstGamepadPetActionStorageSlotIndex
        IsValidGamepadActionStorageSlotIndex IsValidGamepadPossessBarStorageSlotIndex
    ]],
    ["C_Garrison"] = [[
        GetAutoCombatDamageClassValues GetAutoMissionBoardState GetAutoMissionEnvironmentEffect GetAutoMissionTargetingInfo
        GetAutoMissionTargetingInfoForSpell GetAutoTroops GetCombatLogSpellInfo GetCurrentCypherEquipmentLevel GetCurrentGarrTalentTreeFriendshipFactionID
        GetCurrentGarrTalentTreeID GetCyphersToNextEquipmentLevel GetFollowerAutoCombatSpells GetFollowerAutoCombatStats GetFollowerMissionCompleteInfo
        GetGarrisonPlotsInstancesForMap GetGarrisonTalentTreeCurrencyTypes GetGarrisonTalentTreeType GetMaxCypherEquipmentLevel GetMissionCompleteEncounters
        GetMissionDeploymentInfo GetMissionEncounterIconInfo GetTalentInfo GetTalentPointsSpentInTalentTree GetTalentTreeIDsByClassID GetTalentTreeInfo
        GetTalentTreeResetInfo GetTalentTreeTalentPointResearchInfo GetTalentUnlockWorldQuest HasAdventures IsAtGarrisonMissionNPC IsEnvironmentCountered
        IsFollowerOnCompletedMission IsLandingPageMinimapButtonVisible IsTalentConditionMet
    ]],
    ["C_GossipInfo"] = [[
        GetActiveQuests GetAvailableQuests GetCompletedOptionDescriptionString GetCustomGossipDescriptionString GetFriendshipReputation
        GetFriendshipReputationRanks GetNumActiveQuests GetNumAvailableQuests GetOptionUIWidgetSetsAndTypesByOptionID GetOptions GetPoiForUiMapID GetPoiInfo
    ]],
    ["C_GuildBank"] = [[
        IsGuildBankEnabled
    ]],
    ["C_GuildInfo"] = [[
        AreGuildEventsEnabled CanEditOfficerNote CanSpeakInGuildChat CanViewOfficerNote GetGuildNewsInfo GetGuildRankOrder GetGuildTabardInfo
        GetPreferredPlaySettings GetPreferredPlaySettingsFeatures IsDiscordStreamSeparate IsEncounterGuildNewsEnabled IsGuildOfficer
        IsGuildRankAssignmentAllowed IsGuildReputationEnabled
    ]],
    ["C_HeirloomInfo"] = [[
        AreAllCollectionFiltersChecked AreAllSourceFiltersChecked IsHeirloomSourceValid IsUsingDefaultFilters
    ]],
    ["C_HouseEditor"] = [[
        GetActiveHouseEditorMode GetHouseEditorAvailability GetHouseEditorModeAvailability GetHouseEditorPlayerType IsHouseEditorActive
        IsHouseEditorModeActive IsHouseEditorStatusAvailable
    ]],
    ["C_HouseExterior"] = [[
        GetCoreFixtureOptionsInfo GetCurrentHouseExteriorSize GetCurrentHouseExteriorType GetHouseExteriorSizeOptions GetHouseExteriorTypeOptions
        GetSelectedFixturePointInfo HasHoveredFixture HasSelectedFixturePoint IsAnyDecorAttachedToCoreFixture IsAnyDecorAttachedToDoor
        IsAnyDecorAttachedToHouseExterior IsAnyDecorAttachedToSelectedFixturePoint IsExteriorDecorHidden
    ]],
    ["C_Housing"] = [[
        CanEditCharter CanTakeReportScreenshot DoesFactionMatchNeighborhood GetCurrentHouseInfo GetCurrentHouseLevelFavor GetCurrentHouseRefundAmount
        GetCurrentNeighborhoodGUID GetHouseLevelFavorForLevel GetHouseLevelRewardsForLevel GetHousingAccessFlags GetMaxHouseLevel GetNeighborhoodTextureSuffix
        GetOthersOwnedHouses GetPlayerOwnedHouses GetTrackedHouseGuid GetUIMapIDForNeighborhood GetVisitCooldownInfo HasHousingExpansionAccess
        IsHousingMarketCartFullRemoveEnabled IsHousingMarketEnabled IsHousingMarketShopEnabled IsHousingServiceEnabled IsInsideHouse IsInsideHouseOrPlot
        IsInsideOwnedHouse IsInsideOwnedHouseOrPlot IsInsideOwnedPlot IsInsidePlot IsOnNeighborhoodMap
    ]],
    ["C_HousingBasicMode"] = [[
        GetHoveredDecorInfo GetSelectedDecorInfo IsDecorSelected IsFreePlaceEnabled IsGridSnapEnabled IsGridVisible IsHouseExteriorHovered
        IsHouseExteriorSelected IsHoveringDecor IsPlacingNewDecor
    ]],
    ["C_HousingBlueprint"] = [[
        CanExportRoom CanExportTypeFromCurrentLocation CanImportTypeFromCurrentLocation GetBlueprintHyperlink GetBlueprintTypeForCode GetExportAvailability
        GetFeatureAvailability GetImportAvailability IsShareCodeValid
    ]],
    ["C_HousingCatalog"] = [[
        GetAllFilterTagGroups GetAllVariantInfosForEntry GetBundleInfo GetCartSizeLimit GetCatalogCategoryAndSubcategoryNames GetCatalogCategoryInfo
        GetCatalogEntryInfo GetCatalogEntryInfoByItem GetCatalogEntryInfoByRecordID GetCatalogEntryRefundTimeStampByRecordID GetCatalogEntryVariantInfo
        GetCatalogSubcategoryInfo GetDecorMaxOwnedCount GetDecorTotalOwnedCount GetDestroyableInstanceCount GetFeaturedBundles GetFeaturedSmallProducts
        GetMarketInfoForDecor HasFeaturedEntries IsPreviewCartItemShown
    ]],
    ["C_HousingCleanupMode"] = [[
        GetHoveredDecorInfo IsHoveringDecor
    ]],
    ["C_HousingCustomizeMode"] = [[
        GetHoveredDecorInfo GetHoveredRoomComponentInfo GetNumDyesToRemoveOnSelectedDecor GetNumDyesToSpendOnSelectedDecor GetPreviewDyesOnSelectedDecor
        GetRecentlyUsedDyes GetRecentlyUsedThemeSets GetRecentlyUsedWallpapers GetSelectedDecorInfo GetSelectedDecorPetInfo GetSelectedRoomComponentInfo
        GetThemeSetInfo GetWallpapersForRoomComponentType IsDecorSelected IsHouseExteriorDoorHovered IsHoveringDecor IsHoveringRoomComponent
        IsRoomComponentSelected
    ]],
    ["C_HousingDecor"] = [[
        GetAllMaxPlacementBudgets GetAllSpentPlacementBudgets GetDecorAssignedPetName GetDecorCanAttachPet GetDecorHyperlink GetDecorIcon
        GetDecorInstanceInfoForGUID GetDecorName GetHoveredDecorInfo GetMaxPetPlacementBudget GetMaxPlacementBudget GetNumDecorPlaced GetNumPreviewDecor
        GetSelectedDecorInfo GetSpentPetPlacementBudget GetSpentPlacementBudget HasMaxPlacementBudget IsDecorSelected IsGridVisible IsHouseExteriorDoorHovered
        IsHouseExteriorHovered IsHoveringDecor IsModeDisabledForPreviewState IsPreviewState
    ]],
    ["C_HousingExpertMode"] = [[
        GetHoveredDecorInfo GetPrecisionSubmode GetPrecisionSubmodeRestriction GetSelectedDecorInfo IsDecorSelected IsGridVisible IsHouseExteriorHovered
        IsHouseExteriorSelected IsHoveringDecor
    ]],
    ["C_HousingInspectMode"] = [[
        GetHoveredDecorGUID IsHoveringDecor IsInInspectMode
    ]],
    ["C_HousingLayout"] = [[
        CanSetViewedFloor GetBaseRoomFloor GetHighestOccupiedFloorIndex GetLowestOccupiedFloorIndex GetNumActiveRooms GetRoomPlacementBudget GetRoomPlayerIsIn
        GetSelectedBlueprintFloorplan GetSelectedDoor GetSelectedFloorplan GetSelectedRoom GetSelectedStairwellRoomCount GetSpentPlacementBudget
        GetViewedFloor HasAnySelections HasRoomPlacementBudget HasSelectedBlueprintFloorplan HasSelectedDoor HasSelectedFloorplan HasSelectedRoom HasStairs
        HasValidConnection IsBaseRoom IsDraggingRoom
    ]],
    ["C_HousingNeighborhood"] = [[
        CanReturnAfterVisitingHouse GetCornerstoneHouseInfo GetCornerstoneNeighborhoodInfo GetCornerstonePurchaseMode GetCurrentNeighborhoodTextureSuffix
        GetDiscountedMovePrice GetMoveCooldownTime GetNeighborhoodMapData GetNeighborhoodName GetNeighborhoodPlotName GetPreviousHouseIdentifier
        HasPermissionToPurchase IsNeighborhoodManager IsNeighborhoodOwner IsPlayerInOtherPlayersPlot IsPlotAvailableForPurchase IsPlotOwnedByPlayer
    ]],
    ["C_ImmersiveInteraction"] = [[
        HasImmersiveInteraction
    ]],
    ["C_IncomingSummon"] = [[
        HasIncomingSummon
    ]],
    ["C_InputInterfaceStyle"] = [[
        GetCurrentStyle
    ]],
    ["C_InstanceEncounter"] = [[
        IsEncounterInProgress IsEncounterLimitingResurrections IsEncounterSuppressingRelease ShouldShowTimelineForEncounter
    ]],
    ["C_InstanceLeaver"] = [[
        IsPlayerLeaver
    ]],
    ["C_InterfaceFileManifest"] = [[
        GetInterfaceArtFiles
    ]],
    ["C_Intl"] = [[
        FindBreaks FindStringMatches GetCharacterProperties GetCurrencyFractionDigits GetCurrencyName GetCurrentLocale GetDisplayName GetSortKey IsNormalized
    ]],
    ["C_InvasionInfo"] = [[
        AreInvasionsAvailable GetInvasionForUiMapID GetInvasionInfo GetInvasionTimeLeft
    ]],
    ["C_IslandsQueue"] = [[
        GetIslandDifficultyInfo GetIslandsMaxGroupSize GetIslandsWeeklyQuestID
    ]],
    ["C_Item"] = [[
        CanBeRefunded CanItemTransmogAppearance CanScrapItem CanViewItemPowers DoesItemContainSpec DoesItemExist DoesItemExistByID
        DoesItemMatchBonusTreeReplacement DoesItemMatchSpellItemCondition DoesItemMatchTargetEnchantingSpell DoesItemMatchTrackJump GetAppliedItemTransmogInfo
        GetBaseItemTransmogInfo GetCurrentItemLevel GetCurrentItemTransmogInfo GetDelvePreviewItemLink GetDelvePreviewItemQuality GetDetailedItemLevelInfo
        GetFirstTriggeredSpellForItem GetItemChildInfo GetItemClassInfo GetItemConversionOutputIcon GetItemCooldown GetItemCount GetItemCreationContext
        GetItemFamily GetItemGUID GetItemGem GetItemGemID GetItemID GetItemIDByGUID GetItemIDForItemInfo GetItemIcon GetItemIconByID GetItemInfo
        GetItemInfoInstant GetItemInventorySlotInfo GetItemInventorySlotKey GetItemInventoryType GetItemInventoryTypeByID GetItemLearnTransmogSet GetItemLink
        GetItemLinkByGUID GetItemLocation GetItemMaxStackSize GetItemMaxStackSizeByID GetItemName GetItemNameByID GetItemNumAddedSockets GetItemNumSockets
        GetItemQuality GetItemQualityByID GetItemQualityColor GetItemSetInfo GetItemSpecInfo GetItemSpell GetItemStatDelta GetItemStats GetItemSubClassInfo
        GetItemUniqueness GetItemUniquenessByID GetItemUpgradeInfo GetLimitedCurrencyItemInfo GetSetBonusesForSpecializationByItemID GetStackCount
        GetWeaponEnchantInfo IsAnimaItemByID IsArtifactPowerItem IsBound IsBoundToAccountUntilEquip IsConsumableItem IsCorruptedItem IsCosmeticItem
        IsCurioItem IsCurrentItem IsDecorItem IsDressableItemByID IsEquippableItem IsEquippedItem IsEquippedItemType IsHarmfulItem IsHelpfulItem
        IsItemBindToAccount IsItemBindToAccountUntilEquip IsItemConduit IsItemConvertibleAndValidForPlayer IsItemCorrupted IsItemCorruptionRelated
        IsItemCorruptionResistant IsItemDataCached IsItemDataCachedByID IsItemGUIDInInventory IsItemInRange IsItemKeystoneByID IsItemSpecificToPlayerClass
        IsLocked IsRelicItem IsUsableItem
    ]],
    ["C_ItemInteraction"] = [[
        GetChargeInfo GetItemConversionCurrencyCost GetItemInteractionInfo GetItemInteractionSpellId
    ]],
    ["C_ItemSocketInfo"] = [[
        GetCurrUIType GetExistingSocketInfo GetExistingSocketLink GetNewSocketInfo GetNewSocketLink GetNumSockets GetSocketItemBoundTradeable
        GetSocketItemInfo GetSocketItemRefundable GetSocketTypes HasBoundGemProposed IsArtifactRelicItem
    ]],
    ["C_ItemUpgrade"] = [[
        CanUpgradeItem GetHighWatermarkForItem GetHighWatermarkForSlot GetHighWatermarkSlotForItem GetItemHyperlink GetItemUpgradeCurrentLevel
        GetItemUpgradeEffect GetItemUpgradeItemInfo GetItemUpgradePvpItemLevelDeltaValues GetNumItemUpgradeEffects IsItemBound
    ]],
    ["C_LFGInfo"] = [[
        AreCrossFactionGroupQueuesAllowed CanPlayerUseGroupFinder CanPlayerUseLFD CanPlayerUseLFR CanPlayerUsePVP CanPlayerUsePremadeGroup
        CanPlayerUseScenarioFinder DoesActivePartyMeetPremadeLaunchCount DoesCrossFactionQueueRequireFullPremade GetActiveLFGDungeonName
        GetAllEntriesForCategory GetDungeonInfo GetLFDLockStates GetLevelUpInstances GetRoleCheckDifficultyDetails IsGroupFinderEnabled IsInLFGFollowerDungeon
        IsInMatchmadeRaidWithoutRoleRequirements IsLFDEnabled IsLFGFollowerDungeon IsLFREnabled
    ]],
    ["C_LFGList"] = [[
        CanActiveEntryUseAutoAccept CanCreateQuestGroup CanCreateScenarioGroup DoesCensoredTextMatch DoesEntryTitleMatchPrebuiltTitle GetActiveEntryInfo
        GetActivityFullName GetActivityGroupInfo GetActivityInfoTable GetAdvancedFilter GetApplicantBestDungeonScore GetApplicantDungeonScoreForListing
        GetApplicantInfo GetApplicantPvpRatingInfoForListing GetAvailableActivityGroups GetFilteredSearchResults GetGroupLeaverCountsByRole
        GetKeystoneForActivity GetLfgCategoryInfo GetOwnedKeystoneActivityAndGroupAndLevel GetPlaystyleString GetPremadeGroupFinderStyle GetSearchResultInfo
        GetSearchResultLeaderInfo GetSearchResultPlayerInfo GetSearchResults HasActiveEntryInfo HasSearchResultInfo IsCensoredActiveEntryUnresolved
        IsPlayerAuthenticatedForLFG IsPlayerValidForEndgameFieldEdits IsPremadeGroupFinderEnabled
    ]],
    ["C_LFGListRoles"] = [[
        GetRoles GetSavedRoles
    ]],
    ["C_LegendaryCrafting"] = [[
        GetRuneforgeItemPreviewInfo GetRuneforgeLegendaryComponentInfo GetRuneforgeLegendaryCost GetRuneforgeLegendaryCraftSpellID
        GetRuneforgeLegendaryCurrencies GetRuneforgeLegendaryUpgradeCost GetRuneforgeModifierInfo GetRuneforgeModifiers GetRuneforgePowerInfo
        GetRuneforgePowerSlots GetRuneforgePowers GetRuneforgePowersByClassSpecAndCovenant IsRuneforgeLegendary IsRuneforgeLegendaryMaxLevel
        IsUpgradeItemValidForRuneforgeLegendary IsValidRuneforgeBaseItem
    ]],
    ["C_LevelLink"] = [[
        IsActionLocked IsSpellLocked
    ]],
    ["C_Loot"] = [[
        GetLootRollDuration IsLegacyLootModeEnabled
    ]],
    ["C_LootHistory"] = [[
        GetAllEncounterInfos GetInfoForEncounter GetLootHistoryTime GetSortedDropsForEncounter GetSortedInfoForDrop
    ]],
    ["C_LootJournal"] = [[
        GetItemSetItems GetItemSets
    ]],
    ["C_LossOfControl"] = [[
        GetActiveLossOfControlData GetActiveLossOfControlDataByUnit GetActiveLossOfControlDataCount GetActiveLossOfControlDataCountByUnit
        GetActiveLossOfControlDuration
    ]],
    ["C_MacOptions"] = [[
        AreOSShortcutsDisabled GetGameBundleName HasNewStyleInputMonitoring IsInputMonitoringEnabled IsMicrophoneEnabled IsUniversalAccessEnabled
    ]],
    ["C_Mail"] = [[
        CanCheckInbox GetCraftingOrderMailInfo HasInboxMoney IsCODEnabled IsCommandPending
    ]],
    ["C_MajorFactions"] = [[
        GetCurrentRenownLevel GetMajorFactionData GetMajorFactionIDs GetMajorFactionProgressionInfo GetMajorFactionRenownInfo GetRenownLevels
        GetRenownNPCFactionID GetRenownRewardsForLevel GetTotalReputationForRenownLevel HasMaximumRenown IsMajorFactionHiddenFromExpansionPage
        IsWeeklyRenownCapped ShouldDisplayMajorFactionAsJourney ShouldUseJourneyRewardTrack
    ]],
    ["C_Map"] = [[
        CanSetUserWaypointOnMap GetAreaInfo GetBestMapForUnit GetBountySetMaps GetFallbackWorldMapID GetMapArtBackgroundAtlas GetMapArtHelpTextPosition
        GetMapArtID GetMapArtLayerTextures GetMapArtLayers GetMapArtZoneTextPosition GetMapBannersForMap GetMapChildrenInfo GetMapDisplayInfo GetMapGroupID
        GetMapGroupMembersInfo GetMapHighlightInfoAtPosition GetMapHighlightPulseInfo GetMapInfo GetMapInfoAtPosition GetMapLevels GetMapLinksForMap
        GetMapPosFromWorldPos GetMapRectOnMap GetMapWorldSize GetPlayerMapPosition GetUserWaypoint GetUserWaypointFromHyperlink GetUserWaypointHyperlink
        GetUserWaypointPositionForMap GetWorldPosFromMapPos HasUserWaypoint IsCityMap IsMapValidForNavBarDropdown
    ]],
    ["C_MapExplorationInfo"] = [[
        GetExploredAreaIDsAtPosition GetExploredMapTextures
    ]],
    ["C_MerchantFrame"] = [[
        GetBuybackItemID GetItemInfo GetMerchantCurrencies GetNumJunkItems IsMerchantItemRefundable IsSellAllJunkEnabled
    ]],
    ["C_Minimap"] = [[
        CanTrackBattlePets GetDefaultTrackingValue GetDrawGroundTextures GetNumQuestPOIWorldEffects GetNumTrackingTypes GetPOITextureCoords GetTrackingFilter
        GetTrackingInfo GetUiMapID GetViewRadius IsFilteredOut IsInsideQuestBlob IsRotateMinimapIgnored IsTrackingAccountCompletedQuests IsTrackingBattlePets
        IsTrackingHiddenQuests ShouldUseHybridMinimap
    ]],
    ["C_ModelInfo"] = [[
        GetModelSceneActorDisplayInfoByID GetModelSceneActorInfoByID GetModelSceneCameraInfoByID GetModelSceneInfoByID
    ]],
    ["C_ModifiedInstance"] = [[
        GetModifiedInstanceInfoFromMapID
    ]],
    ["C_MountJournal"] = [[
        AreMountEquipmentEffectsSuppressed GetAllCreatureDisplayIDsForMountID GetAppliedMountEquipmentID GetCollectedDragonridingMounts
        GetCollectedFilterSetting GetDisplayedMountAllCreatureDisplayInfo GetDisplayedMountID GetDisplayedMountInfo GetDisplayedMountInfoExtra
        GetDynamicFlightModeSpellID GetIsFavorite GetMountAllCreatureDisplayInfoByID GetMountEquipmentUnlockLevel GetMountFromItem GetMountFromSpell
        GetMountIDs GetMountInfoByID GetMountInfoExtraByID GetMountLink GetMountUsabilityByID GetNumDisplayedMounts GetNumMounts GetNumMountsNeedingFanfare
        HasDisplayableMount IsDragonridingUnlocked IsItemMountEquipment IsMountEquipmentApplied IsSourceChecked IsTypeChecked IsUsingDefaultFilters
        IsValidSourceFilter IsValidTypeFilter
    ]],
    ["C_MythicPlus"] = [[
        GetCurrentAffixes GetCurrentSeason GetCurrentSeasonValues GetCurrentUIDisplaySeason GetEndOfRunGearSequenceLevel GetLastWeeklyBestInformation
        GetOwnedKeystoneChallengeMapID GetOwnedKeystoneLevel GetOwnedKeystoneMapID GetRewardLevelForDifficultyLevel GetRewardLevelFromKeystoneLevel
        GetRunHistory GetSeasonBestAffixScoreInfoForMap GetSeasonBestForMap GetSeasonBestMythicRatingFromThisExpansion GetWeeklyBestForMap
        GetWeeklyChestRewardLevel IsMythicPlusActive
    ]],
    ["C_NamePlate"] = [[
        GetNamePlateForUnit GetNamePlateSize GetNamePlates
    ]],
    ["C_NamePlateManager"] = [[
        GetNamePlateHitTestInsets IsNamePlateUnitBehindCamera
    ]],
    ["C_Navigation"] = [[
        GetDistance GetFrame GetNextWaypointForMap GetTargetState HasValidScreenPosition
    ]],
    ["C_NeighborhoodInitiative"] = [[
        GetActiveNeighborhood GetAvailableHouseXP GetInitiativeActivityLogInfo GetInitiativeTaskChatLink GetInitiativeTaskInfo GetInitiativeTaskRewardScaling
        GetNeighborhoodInitiativeInfo GetRequiredLevel GetTrackedInitiativeTasks IsInitiativeEnabled IsPlayerInNeighborhoodGroup IsViewingActiveNeighborhood
        PlayerHasInitiativeAccess
    ]],
    ["C_NewItems"] = [[
        IsNewItem
    ]],
    ["C_PaperDollInfo"] = [[
        CanAutoEquipCursorItem GetArmorEffectiveness GetArmorEffectivenessAgainstTarget GetInspectAzeriteItemEmpoweredChoices GetInspectGuildInfo
        GetInspectItemLevel GetInspectRatedBGBlitzData GetInspectRatedBGData GetInspectRatedSoloShuffleData GetInventorySlotInfo
        GetInventorySlotInfoForInvSlot GetMinItemLevel GetStaggerPercentage GetTemporaryEnchantmentInfo IsInventorySlotEnabled IsRangedSlotShown
    ]],
    ["C_PartyInfo"] = [[
        CanFormCrossFactionParties CanInvite CanStartInstanceAbandonVote GetActiveCategories GetAvailableLootMethods GetInstanceAbandonShutdownTime
        GetInstanceAbandonVoteCooldownTime GetInstanceAbandonVoteRequirements GetInstanceAbandonVoteResponse GetInstanceAbandonVoteTime
        GetInviteConfirmationInvalidQueues GetInviteReferralInfo GetLootMethod GetLootMethodStyle GetMinItemLevel GetMinLevel
        GetNumInstanceAbandonGroupVoteResponses GetRestrictPings IsChallengeModeActive IsChallengeModeKeystoneOwner IsCrossFactionParty IsDelveComplete
        IsDelveInProgress IsGUIDInGroup IsLootMethodAvailable IsPartyFull IsPartyInJailersTower IsPartyWalkIn IsRaidListEnabled IsRaidListSupported
    ]],
    ["C_PartyPose"] = [[
        GetPartyPoseInfoByID GetPartyPoseInfoByMapID HasExtraAction
    ]],
    ["C_PerksActivities"] = [[
        GetAllPerksActivityTags GetPerksActivitiesInfo GetPerksActivitiesPendingCompletion GetPerksActivityChatLink GetPerksActivityInfo GetPerksUIThemePrefix
        GetTrackedPerksActivities
    ]],
    ["C_PerksProgram"] = [[
        GetAvailableCategoryIDs GetAvailableVendorItemIDs GetCategoryInfo GetCurrencyAmount GetDraggedPerksVendorItem GetFrozenPerksVendorItemInfo
        GetPendingChestRewards GetPerksProgramItemDisplayInfo GetTimeRemaining GetVendorItemInfo GetVendorItemInfoRefundTimeLeft IsAttackAnimToggleEnabled
        IsFrozenPerksVendorItem IsMountSpecialAnimToggleEnabled
    ]],
    ["C_PetBattles"] = [[
        GetBreedQuality GetIcon GetName IsPlayerNPC IsWildBattle
    ]],
    ["C_PetInfo"] = [[
        CanPetEatItem GetPetFoodTypes GetPetHappiness GetPetLoyalty GetPetTalentTree GetPetTamersForMap GetPetTrainingPoints GetPetUIModelSceneID
        GetSpellForPetAction IsPetActionPassive IsPetOrderMoveToPending
    ]],
    ["C_PetJournal"] = [[
        GetDisplayIDByIndex GetDisplayProbabilityByIndex GetNonBattlePetLinkByIndex GetNumDisplays GetNumPetsInJournal GetOwnedPetIDs GetPetAbilityInfo
        GetPetAbilityListTable GetPetInfoTableByPetID GetPetInfoTableBySpeciesID GetPetLoadOutInfo GetPetSummonInfo GetSearchFilter HasFavoritePets
        IsCurrentlySummoned IsUsingDefaultFilters
    ]],
    ["C_Ping"] = [[
        GetCooldownInfo GetDefaultPingOptions GetTextureKitForType IsPingSystemEnabled
    ]],
    ["C_PlayerChoice"] = [[
        GetCurrentPlayerChoiceInfo GetNumRerolls GetRemainingTime IsWaitingForPlayerChoiceResponse
    ]],
    ["C_PlayerInfo"] = [[
        CanPlayerEnterChromieTime CanPlayerUseAreaLoot CanPlayerUseMountEquipment CanUseItem GetAlternateFormInfo GetClass
        GetContentDifficultyCreatureForPlayer GetContentDifficultyQuestForPlayer GetDisplayID GetGlidingInfo GetInstancesUnlockedAtLevel GetName
        GetNativeDisplayID GetPetStableCreatureDisplayInfoID GetPlayerCharacterData GetPlayerMythicPlusRatingSummary GetRace GetSex HasAccountInventoryLock
        HasVisibleInvSlot IsAccountBankEnabled IsCharacterBankEnabled IsConnected IsDisplayRaceNative IsExpansionLandingPageUnlockedForPlayer IsMirrorImage
        IsPlayerEligibleForNPE IsPlayerEligibleForNPEv2 IsPlayerInChromieTime IsPlayerInRPE IsPlayerInTimerunningHeroicWorldTier IsPlayerNPERestricted
        IsReturningCharacter IsSelfFoundActive IsTradingPostAvailable IsTravelersLogAvailable IsTutorialsTabAvailable ShouldDisplaySurname UnitIsSameServer
    ]],
    ["C_PlayerInteractionManager"] = [[
        IsInteractingWithNpcOfType IsReplacingUnit IsValidNPCInteraction
    ]],
    ["C_PlayerMentorship"] = [[
        GetMentorLevelRequirement GetMentorRequirements GetMentorshipStatus IsActivePlayerConsideredNewcomer IsMentorRestricted
    ]],
    ["C_ProfSpecs"] = [[
        CanRefundPath CanUnlockTab GetChildrenForPath GetConfigIDForSkillLine GetCurrencyInfoForSkillLine GetDefaultSpecSkillLine GetDescriptionForPath
        GetDescriptionForPerk GetEntryIDForPerk GetNewSpecReminderProfName GetPerksForPath GetRootPathForTab GetSourceTextForPath GetSpecTabIDsForSkillLine
        GetSpecTabInfo GetSpendCurrencyForPath GetSpendEntryForPath GetStateForPath GetStateForPerk GetStateForTab GetTabInfo GetUnlockEntryForPath
        GetUnlockRankForPerk ShouldShowPointsReminder ShouldShowPointsReminderForSkillLine ShouldShowSpecTab
    ]],
    ["C_PvP"] = [[
        ArePvpTalentsUnlocked AreTrainingGroundsEnabled CanDisplayDeaths CanDisplayHonorableKills CanPlayerUseRatedPVPUI CanPlayerUseTrainingGroundsUI
        CanSurrenderArena CanToggleWarMode CanToggleWarModeInArea DoesMatchOutcomeAffectRating GetActiveBrawlInfo GetActiveMatchBracket GetActiveMatchDuration
        GetActiveMatchState GetActiveMatchWinner GetArenaCrowdControlDuration GetArenaCrowdControlInfo GetArenaOpponentSpec GetArenaRewards
        GetArenaSkirmishRewards GetAssignedSpecForBattlefieldQueue GetAvailableBrawlInfo GetBattlefieldFlagPosition GetBattlefieldVehicleInfo
        GetBattlefieldVehicles GetBattlegroundInfo GetBrawlRewards GetBrawlSoloRBGMinItemLevel GetCustomVictoryStatID GetGlobalPvpScalingInfoForSpecID
        GetHonorRewardInfo GetLevelUpBattlegrounds GetMatchPVPStatColumn GetMatchPVPStatColumns GetNextHonorLevelForReward GetOutdoorPvPWaitTime
        GetPVPActiveMatchPersonalRatedInfo GetPVPActiveRatedMatchDeserterPenalty GetPVPSeasonRewardAchievementID GetPersonalRatedBGBlitzSpecStats
        GetPersonalRatedSoloShuffleSpecStats GetPostMatchCurrencyRewards GetPostMatchItemRewards GetPvpTalentsUnlockedLevel GetPvpTierID GetPvpTierInfo
        GetRandomBGInfo GetRandomBGRewards GetRandomEpicBGInfo GetRandomEpicBGRewards GetRandomTrainingGroundArenaRewards GetRandomTrainingGroundBGRewards
        GetRatedBGRewards GetRatedSoloRBGMinItemLevel GetRatedSoloRBGRewards GetRatedSoloShuffleMinItemLevel GetRatedSoloShuffleRewards
        GetRewardItemLevelsByTierEnum GetScoreInfo GetScoreInfoByPlayerGuid GetSeasonBestInfo GetSkirmishInfo GetSpecialEventBrawlInfo GetTeamInfo
        GetTrainingGrounds GetUIDisplaySeason GetWarModeRewardBonus GetWarModeRewardBonusDefault GetWeeklyChestInfo GetZonePVPInfo HasArenaSkirmishWinToday
        HasMatchStarted HasRandomTrainingGroundArenaWinToday HasRandomTrainingGroundBGWinToday IsActiveBattlefield IsActiveMatchRegistered IsArena
        IsBattleground IsBattlegroundEnlistmentBonusActive IsBrawlSoloRBG IsBrawlSoloShuffle IsInBrawl IsInRatedMatchWithDeserterPenalty IsMatchActive
        IsMatchComplete IsMatchConsideredArena IsMatchFactional IsPVPMap IsRatedArena IsRatedBattleground IsRatedMap IsRatedSoloRBG IsRatedSoloShuffle
        IsSoloRBG IsSoloShuffle IsSubZonePVPPOI IsTrainingGroundsArena IsTrainingGroundsBG IsWarModeActive IsWarModeDesired IsWarModeFeatureEnabled
    ]],
    ["C_QuestHub"] = [[
        IsAreaPOICurrentlyRelatedToHub IsQuestCurrentlyRelatedToHub
    ]],
    ["C_QuestInfoSystem"] = [[
        GetQuestClassification GetQuestHasShortExpirationWarning GetQuestLogRewardFavor GetQuestRewardCurrencies GetQuestRewardSpellInfo GetQuestRewardSpells
        GetQuestShouldToastCompletion HasQuestRewardCurrencies HasQuestRewardSpells
    ]],
    ["C_QuestItemUse"] = [[
        CanUseQuestItemOnObject
    ]],
    ["C_QuestLine"] = [[
        GetAvailableQuestLines GetForceVisibleQuests GetQuestLineInfo GetQuestLineQuests IsComplete
    ]],
    ["C_QuestLog"] = [[
        CanAbandonQuest DoesQuestAwardReputationWithFaction GetAbandonQuest GetAbandonQuestItems GetActivePreyQuest GetActiveThreatMaps
        GetAllCompletedQuestIDs GetBountiesForMapID GetBountySetInfoForMapID GetDistanceSqToQuest GetHeaderIndexForQuest GetInfo GetLogIndexForQuestID
        GetMapForQuestPOIs GetMaxNumQuests GetMaxNumQuestsCanAccept GetNextWaypoint GetNextWaypointForMap GetNextWaypointText GetNumQuestLogEntries
        GetNumQuestObjectives GetNumQuestWatches GetNumWorldQuestWatches GetQuestAdditionalHighlights GetQuestDetailsTheme GetQuestDifficultyLevel
        GetQuestIDForLogIndex GetQuestIDForQuestWatchIndex GetQuestIDForWorldQuestWatchIndex GetQuestLogMajorFactionReputationRewards GetQuestLogPortraitGiver
        GetQuestObjectives GetQuestRewardCurrencies GetQuestRewardCurrencyInfo GetQuestTagInfo GetQuestTimers GetQuestType GetQuestWatchType GetQuestsOnMap
        GetRequiredMoney GetSelectedQuest GetSuggestedGroupSize GetTimeAllowed GetTitleForLogIndex GetTitleForQuestID GetTrivialRange GetZoneStoryInfo
        HasActiveThreats IsAccountQuest IsComplete IsEliteQuest IsFailed IsImportantQuest IsMetaQuest IsOnMap IsOnQuest IsPushableQuest IsQuestBounty
        IsQuestCalling IsQuestCriteriaForBounty IsQuestDisabledForSession IsQuestFlaggedCompleted IsQuestFlaggedCompletedOnAccount IsQuestFromContentPush
        IsQuestInvasion IsQuestReplayable IsQuestReplayedRecently IsQuestTask IsQuestTrivial IsRepeatableQuest IsThreatQuest IsUnitOnQuest IsWorldQuest
        ShouldDisplayTimeRemaining ShouldShowQuestRewards UnitIsRelatedToActiveQuest
    ]],
    ["C_QuestOffer"] = [[
        GetHideRequiredItems GetQuestOfferMajorFactionReputationRewards GetQuestRequiredCurrencyInfo GetQuestRewardCurrencyInfo
    ]],
    ["C_QuestSession"] = [[
        CanStart CanStop GetAvailableSessionCommand GetPendingCommand GetProposedMaxLevelForSession GetSessionBeginDetails GetSuperTrackedQuest HasJoined
        HasPendingCommand
    ]],
    ["C_RaidLocks"] = [[
        GetRedirectedDifficultyID IsEncounterComplete IsRaidLockExtendFeatureEnabled IsRaidLockExtendFeatureSupported
    ]],
    ["C_RecentAllies"] = [[
        CanSetRecentAllyNote GetRecentAllies GetRecentAllyByFullName GetRecentAllyByGUID IsInteractionCategoryFilterSupportedForCurrentGameType
        IsRecentAllyByFullName IsRecentAllyByGUID IsRecentAllyDataReady IsRecentAllyPinned IsSystemEnabled IsSystemSupported
    ]],
    ["C_RemixArtifactUI"] = [[
        GetAppearanceInfoByID GetArtifactArtInfo GetArtifactItemInfo GetCurrArtifactItemID GetCurrItemSpecIndex GetCurrTraitTreeID
    ]],
    ["C_Reputation"] = [[
        AreLegacyReputationsShown GetFactionDataByID GetFactionDataByIndex GetFactionParagonInfo GetGuildFactionData GetGuildRepExpirationTime GetNumFactions
        GetReputationSortType GetSelectedFaction GetWatchedFactionData IsAccountWideReputation IsFactionActive IsFactionParagon
        IsFactionParagonForCurrentPlayer IsMajorFaction
    ]],
    ["C_ResearchInfo"] = [[
        GetDigSitesForMap
    ]],
    ["C_Roleset"] = [[
        GetActiveAllowedRolesets GetActiveBlockedRolesets
    ]],
    ["C_ScenarioInfo"] = [[
        GetCriteriaInfo GetCriteriaInfoByStep GetDisplayInfo GetJailersTowerTypeString GetScenarioIconInfo GetScenarioInfo GetScenarioStepInfo
        GetTieredEntranceActiveSpells GetUnitCriteriaProgressValues IsTieredEntranceScenario
    ]],
    ["C_ScrappingMachineUI"] = [[
        GetCurrentPendingScrapItemLocationByIndex GetScrapSpellID GetScrappingMachineName HasScrappableItems
    ]],
    ["C_SeasonInfo"] = [[
        GetCurrentDisplaySeasonExpansion GetCurrentDisplaySeasonID GetTimeUntilCurrentPVPSeasonEnd
    ]],
    ["C_SkillInfo"] = [[
        GetNumSkillLines GetSelectedSkill GetSkillLineInfo GetSkillLineInfoByID
    ]],
    ["C_Soulbinds"] = [[
        CanActivateSoulbind CanModifySoulbind CanResetConduitsInSoulbind CanSwitchActiveSoulbindTreeBranch FindNodeIDActuallyInstalled
        FindNodeIDAppearingInstalled FindNodeIDPendingInstall FindNodeIDPendingUninstall GetActiveSoulbindID GetConduitCollection GetConduitCollectionCount
        GetConduitCollectionData GetConduitCollectionDataAtCursor GetConduitCollectionDataByVirtualID GetConduitDisplayed GetConduitHyperlink
        GetConduitIDPendingInstall GetConduitQuality GetConduitRank GetConduitSpellID GetInstalledConduitID GetNode GetSoulbindData GetSpecsAssignedToSoulbind
        GetTree HasAnyInstalledConduitInSoulbind HasAnyPendingConduits HasPendingConduitsInSoulbind IsConduitInstalled IsConduitInstalledInSoulbind
        IsItemConduitByItemInfo IsNodePendingModify IsUnselectedConduitPendingInSoulbind
    ]],
    ["C_Sound"] = [[
        GetSoundScaledVolume IsPlaying
    ]],
    ["C_SpecializationInfo"] = [[
        CanPlayerUsePVPTalentUI CanPlayerUseTalentSpecUI CanPlayerUseTalentUI GetActiveSpecGroup GetAllClassIDs GetAllSelectedPvpTalentIDs
        GetClassIDFromSpecID GetCombatConfigIDForSpecGroup GetInspectSelectedPvpTalent GetInspectSpecialization GetNumSpecializationsForClassID
        GetPvpTalentAlertStatus GetPvpTalentInfo GetPvpTalentSlotInfo GetPvpTalentSlotUnlockLevel GetPvpTalentUnlockLevel GetSpecIDs GetSpecialization
        GetSpecializationInfo GetSpecializationMasterySpells GetSpellsDisplay GetTalentInfo HasPlayerEarnedATalentPoint IsInitialized IsPvpTalentLocked
        IsSpecSelectionEnabled
    ]],
    ["C_Spell"] = [[
        DoesSpellExist GetAuraStatChanges GetBaseSpell GetDeadlyDebuffInfo GetItemCooldown GetItemModifiedAppearancesApplied GetLastCategoryCooldownSource
        GetMawPowerLinkBySpellID GetMawPowerRarityInfoBySpellID GetOverrideSpell GetSchoolString GetSpellAutoCast GetSpellCastCount GetSpellChargeDuration
        GetSpellCharges GetSpellCooldown GetSpellCooldownDuration GetSpellDescription GetSpellDescriptionForItemLocation GetSpellDisplayCount
        GetSpellIDForSpellIdentifier GetSpellInfo GetSpellLevelLearned GetSpellLink GetSpellLossOfControlCooldownDuration GetSpellLossOfControlCooldownInfo
        GetSpellMaxCumulativeAuraApplications GetSpellName GetSpellPowerCost GetSpellQueueWindow GetSpellSkillLineAbilityRank GetSpellSubtext GetSpellTexture
        GetSpellTradeSkillLink GetTargetSpellID GetVisibilityInfo IsActiveSpell IsAutoAttackSpell IsAutoRepeatSpell IsClassTalentSpell IsConsumableSpell
        IsCurrentSpell IsExternalDefensive IsPressHoldReleaseSpell IsPriorityAura IsPvPTalentSpell IsRangedAutoAttackSpell IsSelfBuff IsSpellCrowdControl
        IsSpellDataCached IsSpellDisabled IsSpellHarmful IsSpellHelpful IsSpellImportant IsSpellInRange IsSpellPassive IsSpellUsable
    ]],
    ["C_SpellActivationOverlay"] = [[
        IsSpellOverlayed
    ]],
    ["C_SpellBook"] = [[
        FindBaseSpellByID FindFlyoutSlotBySpellID FindSpellBookSlotForSpell FindSpellOverrideByID GetClassSkillLineInfo GetCurrentLevelSpells
        GetNumSpellBookSkillLines GetSkillLineIndexByID GetSpellBookItemAutoCast GetSpellBookItemCastCount GetSpellBookItemChargeDuration
        GetSpellBookItemCharges GetSpellBookItemCooldown GetSpellBookItemCooldownDuration GetSpellBookItemDescription GetSpellBookItemInfo
        GetSpellBookItemLevelLearned GetSpellBookItemLink GetSpellBookItemLossOfControlCooldownDuration GetSpellBookItemLossOfControlCooldownInfo
        GetSpellBookItemName GetSpellBookItemPowerCost GetSpellBookItemSkillLineIndex GetSpellBookItemTexture GetSpellBookItemTradeSkillLink
        GetSpellBookItemType GetSpellBookSkillLineInfo HasPetSpells IsAutoAttackSpellBookItem IsClassTalentSpellBookItem IsPvPTalentSpellBookItem
        IsRangedAutoAttackSpellBookItem IsSpellBookItemHarmful IsSpellBookItemHelpful IsSpellBookItemInRange IsSpellBookItemLooseFlyoutMember
        IsSpellBookItemLowRank IsSpellBookItemOffSpec IsSpellBookItemPassive IsSpellBookItemUsable IsSpellInSpellBook IsSpellKnown IsSpellKnownOrInSpellBook
    ]],
    ["C_SpellDiminish"] = [[
        GetAllSpellDiminishCategories GetSpellDiminishCategoryInfo IsSystemSupported ShouldTrackSpellDiminishCategory
    ]],
    ["C_SplashScreen"] = [[
        CanViewSplashScreen
    ]],
    ["C_StableInfo"] = [[
        GetActivePetList GetAvailablePetSpecInfos GetNextStableSlotCost GetNumActivePets GetNumStablePets GetNumStableSlots GetStablePetFoodTypes
        GetStablePetInfo GetStabledPetList IsAtStableMaster IsBonusPetSlotAvailable IsPetFavorite
    ]],
    ["C_SummonInfo"] = [[
        GetSummonConfirmAreaName GetSummonConfirmSummoner GetSummonConfirmTimeLeft GetSummonReason IsSummonSkippingStartExperience
    ]],
    ["C_SuperTrack"] = [[
        GetHighestPrioritySuperTrackingType GetSuperTrackedContent GetSuperTrackedItemName GetSuperTrackedMapPin GetSuperTrackedQuestID
        GetSuperTrackedVignette IsSuperTrackingAnything IsSuperTrackingContent IsSuperTrackingCorpse IsSuperTrackingMapPin IsSuperTrackingQuest
        IsSuperTrackingUserWaypoint
    ]],
    ["C_SwingTimer"] = [[
        IsTargetWithinSwingRange
    ]],
    ["C_TTSSettings"] = [[
        GetChannelEnabled GetCharacterSettingsSaved GetChatTypeEnabled GetSetting GetSpeechRate GetSpeechVolume GetVoiceOptionID GetVoiceOptionName
        ShouldOverrideMessage
    ]],
    ["C_TaskQuest"] = [[
        DoesMapShowTaskQuestObjectives GetQuestInfoByQuestID GetQuestLocation GetQuestProgressBarInfo GetQuestTimeLeftMinutes GetQuestTimeLeftSeconds
        GetQuestUIWidgetSetByType GetQuestZoneID GetQuestsOnMap GetThreatQuests IsActive
    ]],
    ["C_TaxiMap"] = [[
        GetAllTaxiNodes GetTaxiNodesForMap ShouldMapShowTaxiNodes
    ]],
    ["C_Texture"] = [[
        GetAtlasElementID GetAtlasElements GetAtlasExists GetAtlasID GetAtlasInfo GetFilenameFromFileDataID GetTitleIconTexture IsTitleIconTextureReady
    ]],
    ["C_TimerunningUI"] = [[
        GetActiveTimerunningSeasonID
    ]],
    ["C_TooltipComparison"] = [[
        GetItemComparisonDelta GetItemComparisonInfo
    ]],
    ["C_TooltipInfo"] = [[
        GetAchievementByID GetAction GetArtifactItem GetArtifactPowerByID GetAzeriteEssence GetAzeriteEssenceSlot GetAzeritePower GetBackpackToken GetBagItem
        GetBagItemChild GetBuybackItem GetCompanionPet GetConduit GetCurrencyByID GetCurrencyToken GetEnhancedConduit GetEquipmentSet GetExistingSocketGem
        GetGuildBankItem GetHeirloomByItemID GetHyperlink GetInboxItem GetInstanceLockEncountersComplete GetInventoryItem GetInventoryItemByID GetItemByGUID
        GetItemByID GetItemByItemModifiedAppearanceID GetItemInteractionItem GetItemKey GetLFGDungeonReward GetLFGDungeonShortageReward GetLootCurrency
        GetLootItem GetLootRollItem GetMerchantCostItem GetMerchantItem GetMinimapMouseover GetMountBySpellID GetOutfit GetOwnedItemByID GetPetAction
        GetPossession GetPvpBrawl GetPvpTalent GetQuestCurrency GetQuestItem GetQuestLogCurrency GetQuestLogItem GetQuestLogSpecialItem GetQuestPartyProgress
        GetRecipeRankInfo GetRecipeReagentItem GetRecipeResultItem GetRecipeResultItemForOrder GetRuneforgeResultItem GetSendMailItem GetShapeshift
        GetSlottedKeystone GetSocketGem GetSocketedItem GetSocketedRelic GetSpellBookItem GetSpellByID GetTalent GetTotem GetToyByItemID GetTradePlayerItem
        GetTradeTargetItem GetTrainerService GetTraitEntry GetUnit GetUnitAura GetUnitAuraByAuraInstanceID GetUnitBuff GetUnitBuffByAuraInstanceID
        GetUnitDebuff GetUnitDebuffByAuraInstanceID GetUpgradeItem GetWorldCursor GetWorldLootObject
    ]],
    ["C_ToyBoxInfo"] = [[
        HasAnyToy IsToySourceValid IsUsingDefaultFilters
    ]],
    ["C_TradeInfo"] = [[
        ShouldShowTradeOfferWarning
    ]],
    ["C_TradeSkillUI"] = [[
        CanStoreEnchantInItem CanTradeSkillShowCraftingUI DoesRecraftingRecipeAcceptItem GetAllProfessionTradeSkillLines GetBaseProfessionInfo
        GetChildProfessionInfo GetChildProfessionInfos GetConcentrationCurrencyID GetCraftableCount GetCraftingOperationInfo GetCraftingOperationInfoForOrder
        GetCraftingReagentBonusText GetCraftingTargetItems GetDependentReagents GetEnchantItems GetFactionSpecificOutputItem GetGatheringOperationInfo
        GetHideUnownedFlags GetItemCraftedQualityByItemInfo GetItemCraftedQualityInfo GetItemReagentQualityByItemInfo GetItemReagentQualityInfo
        GetItemSlotModifications GetItemSlotModificationsForOrder GetOriginalCraftRecipeID GetProfessionByInventorySlot GetProfessionChildSkillLineID
        GetProfessionForCursorItem GetProfessionInfoByRecipeID GetProfessionInfoBySkillLineID GetProfessionInventorySlots GetProfessionNameForSkillLineAbility
        GetProfessionSkillLineID GetProfessionSlots GetProfessionSpells GetQualitiesForRecipe GetReagentDifficultyText GetReagentSlotStatus
        GetRecipeDescription GetRecipeInfo GetRecipeInfoForSkillLineAbility GetRecipeItemQualityInfo GetRecipeOutputItemData GetRecipeQualityItemIDs
        GetRecipeQualityReagentLink GetRecipeRequirements GetRecipeSchematic GetRecipesTracked GetRecraftItems GetRecraftRemovalWarnings GetRemainingRecasts
        GetSalvagableItemIDs GetShowLearned GetShowUnlearned GetSkillLineForGear GetSourceTypeFilter GetTradeSkillDisplayName HasFavoriteOrderRecipes
        HasNoReagentCost IsEnchantTargetValid IsGuildTradeSkillsEnabled IsNPCCrafting IsNearProfessionSpellFocus IsOriginalCraftRecipeLearned
        IsRecipeFirstCraft IsRecipeInBaseSkillLine IsRecipeInSkillLine IsRecipeProfessionLearned IsRecipeTracked IsRecraftItemEquipped IsRecraftReagentValid
        IsRuneforging
    ]],
    ["C_Trainer"] = [[
        GetCategorizeTrainerUI GetTrainerType
    ]],
    ["C_Traits"] = [[
        CanEditConfig CanPurchaseRank CanRefundRank GetConditionInfo GetConfigIDBySystemID GetConfigIDByTreeID GetConfigInfo GetConfigVariationID
        GetConfigsByType GetDefinitionInfo GetEntryInfo GetGroupCurrencyInfo GetGroupDisplayInfoByTreeID GetIncreasedTraitData GetLoadoutSerializationVersion
        GetMaxAvailableTraitCurrency GetNodeCost GetNodeInfo GetStagedChanges GetStagedChangesCost GetSubTreeInfo GetSystemIDByTreeID
        GetTraitCurrencyForAchievement GetTraitCurrencyInfo GetTraitDescription GetTraitSystemFlags GetTraitSystemWidgetSetID GetTreeCurrencyInfo GetTreeHash
        GetTreeInfo GetTreeNodes HasValidInspectData IsReadyForCommit
    ]],
    ["C_Transmog"] = [[
        CanHaveSecondaryAppearanceForSlotID GetAllSetAppearancesByID GetItemIDForSource GetSlotForInventoryType GetSlotVisualInfo IsAtTransmogNPC
    ]],
    ["C_TransmogCollection"] = [[
        AreAllCollectionTypeFiltersChecked AreAllSourceTypeFiltersChecked CanAppearanceHaveIllusion GetAllAppearanceSources GetAllFactionsShown
        GetAllRacesShown GetAppearanceCameraID GetAppearanceCameraIDBySource GetAppearanceInfoBySource GetAppearanceSourceDrops GetAppearanceSourceInfo
        GetAppearanceSources GetArtifactAppearanceStrings GetCategoryAppearances GetCategoryCollectedCount GetCategoryForItem GetCategoryInfo GetCategoryTotal
        GetClassFilter GetCollectedShown GetCustomSetHyperlinkFromItemTransmogInfoList GetCustomSetInfo GetCustomSetItemTransmogInfoList GetCustomSets
        GetFallbackWeaponAppearance GetFilteredCategoryCollectedCount GetFilteredCategoryTotal GetIllusionInfo GetIllusionStrings GetIllusions
        GetInspectItemTransmogInfoList GetIsAppearanceFavorite GetItemInfo GetItemTransmogInfoListFromCustomSetHyperlink GetLatestAppearance
        GetNumMaxCustomSets GetNumTransmogSources GetPairedArtifactAppearance GetSourceIcon GetSourceInfo GetSourceItemID GetSourceRequiredHoliday
        GetUncollectedShown GetValidAppearanceSourcesForClass HasAnyAppearance HasFavorites IsAppearanceHiddenVisual IsCategoryValidForItem IsNewAppearance
        IsSearchDBLoading IsSearchInProgress IsSourceTypeFilterChecked IsSpellItemEnchantmentHiddenVisual IsUsingDefaultFilters IsValidCustomSetName
        IsValidTransmogSource PlayerCanCollectSource PlayerHasTransmog PlayerHasTransmogByItemInfo PlayerHasTransmogItemModifiedAppearance
    ]],
    ["C_TransmogOutfitInfo"] = [[
        CanPlayerTransmogSlot GetActiveOutfitID GetAllSlotLocationInfo GetAllTransmogOutfitOptionSheatheCategoryInfo GetCollectionInfoForSlotAndOption
        GetCurrentlyViewedOutfitID GetEquippedSlotOptionFromTransmogSlot GetIllusionDefaultIMAIDForCollectionType GetItemModifiedAppearanceEffectiveCategory
        GetLinkedSlotInfo GetMaxNumberOfTotalOutfitsForSource GetMaxNumberOfUsableOutfits GetNextOutfitCost GetNumberOfOutfitsUnlockedForSource
        GetOptionsForSlot GetOutfitInfo GetOutfitInfoByName GetOutfitInfoByPlayerFacingIndex GetOutfitSituation GetOutfitSituationsEnabled GetOutfitsInfo
        GetPendingTransmogCost GetSecondarySlotState GetSetSourcesForSlot GetSlotGroupInfo GetSourceIDsForSlot GetTransmogOutfitSlotForInventoryType
        GetTransmogOutfitSlotFromInventorySlot GetUISituationCategoriesAndOptions GetUnassignedAtlasForSlot GetUnassignedDisplayAtlasForSlot
        GetViewedOutfitSlotInfo HasPendingOutfitSituations HasPendingOutfitTransmogs IsEquippedGearOutfitDisplayed IsEquippedGearOutfitLocked IsLockedOutfit
        IsSlotWeaponSlot IsTransmogEnabled IsUsableDiscountAvailable IsValidTransmogOutfitName
    ]],
    ["C_TransmogSets"] = [[
        GetAllSets GetAllSourceIDs GetAvailableSets GetBaseSetID GetBaseSets GetBaseSetsFilter GetCameraIDs GetFilteredBaseSetsCounts GetFullBaseSetsCounts
        GetIsFavorite GetLatestSource GetSetInfo GetSetNewSources GetSetPrimaryAppearances GetSetsContainingSourceID GetSetsFilter GetSourceIDsForSlot
        GetSourcesForSlot GetTransmogSetsClassFilter GetUsableSets GetValidBaseSetsCountsForCharacter GetValidClassForSet GetVariantSets HasAnyValidSets
        HasAvailableSets HasUsableSets IsBaseSetCollected IsNewSource IsSetVisible IsUsingDefaultBaseSetsFilters IsUsingDefaultSetsFilters
    ]],
    ["C_Tutorial"] = [[
        GetCombatEventInfo
    ]],
    ["C_UI"] = [[
        DoesAnyDisplayHaveNotch GetTopLeftNotchSafeRegion GetTopRightNotchSafeRegion GetUIParent GetWorldFrame ShouldUIParentAvoidNotch
    ]],
    ["C_UIColor"] = [[
        GetColors
    ]],
    ["C_UIFileAsset"] = [[
        GetFileID IsKnownFile IsLooseFile
    ]],
    ["C_UnitAuras"] = [[
        DoesAuraHaveExpirationTime GetAuraApplicationDisplayCount GetAuraBaseDuration GetAuraCasterGUID GetAuraDataByAuraInstanceID GetAuraDataByIndex
        GetAuraDataBySlot GetAuraDataBySpellName GetAuraDispelTypeColor GetAuraDuration GetAuraSlots GetBuffDataByIndex GetCooldownAuraBySpellID
        GetDebuffDataByIndex GetGroupBuffVisualAlerts GetHiddenGroupBuffs GetPlayerAuraBySpellID GetRefreshCarryOverDuration GetRefreshExtendedDuration
        GetUnitAuraBySpellID GetUnitAuraInstanceIDs GetUnitAuras IsAuraFilteredOutByInstanceID
    ]],
    ["C_VideoOptions"] = [[
        AreHighResTexturesAvailable GetCurrentGameWindowSize GetDefaultGameWindowSize GetGameWindowSizes GetGxAdapterInfo IsLinearEnabledOnStart
        IsOutlineModeSupported IsPBRWaterSupported IsSecondaryLightingSupported IsSpellVisualDensitySystemSupported
    ]],
    ["C_VignetteInfo"] = [[
        FindBestUniqueVignette GetHealthPercent GetRecommendedGroupSize GetVignetteInfo GetVignettePosition GetVignettes
    ]],
    ["C_WarbandScene"] = [[
        GetRandomEntryID GetWarbandSceneEntry HasWarbandScene IsFavorite
    ]],
    ["C_Weather"] = [[
        GetCurrentWeather
    ]],
    ["C_WeeklyRewards"] = [[
        AreRewardsForCurrentRewardPeriod CanClaimRewards GetActivities GetActivityEncounterInfo GetConquestWeeklyProgress GetDifficultyIDForActivityTier
        GetExampleRewardItemHyperlinks GetItemHyperlink GetNextActivitiesIncrease GetNextMythicPlusIncrease GetNumCompletedDungeonRuns
        GetSortedProgressForActivity HasAvailableRewards HasGeneratedRewards HasInteraction IsWeeklyChestRetired ShouldShowFinalRetirementMessage
        ShouldShowRetirementMessage
    ]],
    ["C_WorldLootObject"] = [[
        DoesSlotMatchInventoryType GetWorldLootObjectDistanceSquared GetWorldLootObjectInfo GetWorldLootObjectInfoByGUID IsWorldLootObject
        IsWorldLootObjectByGUID IsWorldLootObjectInRange
    ]],
    ["C_WorldSafeLocsUIInternal"] = [[
        GetWorldSafeLocs
    ]],
    ["C_ZoneAbility"] = [[
        GetActiveAbilities GetZoneAbilityIcon
    ]],
}
