
Ç
msg/common.proto
msg.common"
Query"+
	Handshake
v1 (	Rv1
v2 (	Rv2"
	Heartbeat*
Result
success
fail
—
msg/ddz.protomsg.ddz"0
ReqPointDemand

userDemand (R
userDemand"_
ReqSendCard
nowType (RnowType
nowValue (RnowValue
cardList (RcardList"u
ServerPointDemand
	userExtra (R	userExtra$
userNowDemand (RuserNowDemand
	userPoint (R	userPoint"l
ServerSendCard
	userExtra (R	userExtra
userCard (RuserCard 
userCardNum (RuserCardNum"Q
NoticePointDemand
	userExtra (R	userExtra

userDemand (R
userDemand"L
NoticeMainPlayer
	userExtra (R	userExtra
baseCard (RbaseCard"ä
Item
user_id (	RuserId
user_pos (RuserPos
	cur_score (RcurScore
score (Rscore
	card_list (RcardList"…
NoticeDDZGameOver
	over_type (RoverType'
players (2.msg.ddz.ItemRplayers
	bIfSpring (R	bIfSpring
iTime (RiTime
	iBoomNums (R	iBoomNums
	iLastCard (R	iLastCard"ƒ
NoticeSendCard
	userExtra (R	userExtra
cCardNum (RcCardNum
	cCardType (R	cCardType

cCardValue (R
cCardValue"
cLestCardNum (RcLestCardNum
cCards (RcCards
‹
msg/login.proto	msg.login"9
LoginReq
user_id (RuserId
token (	Rtoken"5
LoginRsp)
result (2.msg.login.ResultRresult*&
	LoginType

weixin
	reconnect*$
Result
success
	auth_fail
È8
msg/user.protomsg.user"H
FastSpakeReq
user_pos (RuserPos

fast_index (	R	fastIndex"K
NoticeFastSpake
user_pos (RuserPos

fast_index (	R	fastIndex"F
GPItem
value (Rvalue
from (Rfrom
type (Rtype"î
UserInfo
user_id (RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_ip (	RuserIp
user_pos (RuserPos
is_sit (RisSit
gold_num (RgoldNum
score (Rscore
	cur_score	 (RcurScore

disconnect
 (R
disconnect"Ö
RoomSetting
	game_type (RgameType
round (Rround
pay_type (RpayType
seat_num (RseatNum$
is_friend_room (RisFriendRoom"
is_open_voice (RisOpenVoice
is_open_gps (R	isOpenGps#
other_setting (RotherSetting"I
CreateRoomReq8
room_setting (2.msg.user.RoomSettingRroomSetting"9
CreateRoomRsp(
result (2.msg.user.ResultRresult"&
JoinRoomReq
room_id (RroomId"7
JoinRoomRsp(
result (2.msg.user.ResultRresult"
LeaveRoomReq"8
LeaveRoomRsp(
result (2.msg.user.ResultRresult"

SitDownReq
pos (Rpos"6

SitDownRsp(
result (2.msg.user.ResultRresult"„

GameCmdReq
command (	Rcommand
card (Rcard 
demandPoint (RdemandPoint
nowType (RnowType
nowValue (RnowValue
cardList (RcardList
cardNums	 (RcardNums
pao_num
 (RpaoNum"6

GameCmdRsp(
result (2.msg.user.ResultRresult"©
RoomItem
room_id (RroomId
state (Rstate
expire_time (R
expireTime
is_sit (RisSit
	game_type (RgameType
owner_id (	RownerId"
GetMyRoomListReq"Ü
GetMyRoomListRsp(
result (2.msg.user.ResultRresult/
	room_list (2.msg.user.RoomItemRroomList
room_id (RroomId"›
PushUserInfo
user_id (RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_ip (	RuserIp
gold_num (RgoldNum/
	room_list (2.msg.user.RoomItemRroomList
room_id (RroomId"@
UpdateRoomState
room_id (RroomId
state (Rstate"≈
RefreshRoomInfo
room_id (RroomId,
players (2.msg.user.UserInfoRplayers8
room_setting (2.msg.user.RoomSettingRroomSetting
state (Rstate
	cur_round (RcurRound"=
SitItem
user_id (RuserId
user_pos (RuserPos"T
PushSitDown
room_id (RroomId,
sit_list (2.msg.user.SitItemRsitList"?
FourCardItem
user_pos (RuserPos
cards (Rcards"Â
DealCard
zpos (Rzpos
user_pos (RuserPos
cards (Rcards
random_nums (R
randomNums
	cur_round (RcurRound<
four_card_list (2.msg.user.FourCardItemRfourCardList
huicard (Rhuicard"V
PushDrawCard
user_id (RuserId
card (Rcard
user_pos (RuserPos"Œ
PushPlayCard
user_id (RuserId
user_pos (RuserPos
operator (Roperator
	card_list (RcardList/

card_stack (2.msg.user.GPItemR	cardStack 
userCardNum (RuserCardNum"X
NoticePlayCard
user_id (RuserId
card (Rcard
user_pos (RuserPos"j
NoticePengCard
user_id (RuserId
user_pos (RuserPos$
item (2.msg.user.GPItemRitem"j
NoticeGangCard
user_id (RuserId
user_pos (RuserPos$
item (2.msg.user.GPItemRitem"n
NoticeSpecailEvent
user_id (RuserId
user_pos (RuserPos$
item (2.msg.user.GPItemRitem"Ü
PushPlayerOperatorState#
operator_list (	RoperatorList
user_pos (RuserPos
user_id (RuserId
card (Rcard"?
NoticeTingCard
user_pos (RuserPos
card (Rcard"ä
Item
user_id (RuserId
user_pos (RuserPos
	cur_score (RcurScore
score (Rscore
	card_list (RcardList"’
NoticeGameOver
	over_type (RoverType(
players (2.msg.user.ItemRplayers

award_list (R	awardList
winner_type (R
winnerType

last_round (R	lastRound

winner_pos (R	winnerPos"m
NoticePlayerConnectState
user_id (RuserId
user_pos (RuserPos

is_connect (R	isConnect":
PutCard
user_pos (RuserPos
cards (Rcards"E
	HandleNum
user_pos (RuserPos

handle_num (R	handleNum"L
	ItemStack$
item (2.msg.user.GPItemRitem
user_pos (RuserPos";
MarkItem
user_pos (RuserPos
cards (Rcards"π
PushAllRoomInfoE
refresh_room_info (2.msg.user.RefreshRoomInfoRrefreshRoomInfo
	card_list (RcardList
operator (	Roperator 
cur_play_pos (R
curPlayPos
zpos (Rzpos.
	put_cards (2.msg.user.PutCardRputCards

reduce_num (R	reduceNum4
handle_nums (2.msg.user.HandleNumR
handleNums
put_card	 (RputCard*
cur_play_operator
 (	RcurPlayOperator
put_pos (RputPos
	operators (	R	operators,
cur_play_operators (	RcurPlayOperators
card (Rcard2

card_stack (2.msg.user.ItemStackR	cardStack&
cur_table_cards (RcurTableCards(
cur_table_Demand (RcurTableDemand*
cur_table_bDouble (RcurTableBDouble$
cur_table_time (RcurTableTime*
cur_last_CardNums (RcurLastCardNums

cBaseCards (R
cBaseCards
huicard (Rhuicard<
four_card_list (2.msg.user.FourCardItemRfourCardList/
	mark_list (2.msg.user.MarkItemRmarkList"Y
GoldItem
user_id (RuserId
user_pos (RuserPos
gold_num (RgoldNum"A
UpdateCostGold/
	gold_list (2.msg.user.GoldItemRgoldList"t
	ScoreItem
user_id (RuserId
user_pos (RuserPos

delt_score (R	deltScore
score (Rscore"R
RefreshPlayerCurScore9
cur_score_list (2.msg.user.ScoreItemRcurScoreList"%
HandleError
result (	Rresult"+
UpdateResource
gold_num (RgoldNum"=
DistroyRoomReq
room_id (RroomId
type (Rtype"(
DistroyRoomRsp
result (	Rresult"\
NoticeOtherDistoryRoom!
distroy_time (RdistroyTime
confirm_map (R
confirmMap"1
ConfirmDistroyRoomReq
confirm (Rconfirm"/
ConfirmDistroyRoomRsp
result (	Rresult"`
NoticeOtherRefuse
user_id (RuserId
room_id (RroomId
user_pos (RuserPos"F
NoticePlayerDistroyRoom
room_id (RroomId
type (Rtype"–

SattleItem
user_id (RuserId
user_pos (RuserPos
hu_num (RhuNum"
ming_gang_num (RmingGangNum
an_gang_num (R	anGangNum

reward_num (R	rewardNum
score (Rscore"Ç
NoticeTotalSattle
room_id (RroomId5
sattle_list (2.msg.user.SattleItemR
sattleList

begin_time (	R	beginTime"
	SendAudio
data (Rdata"&
SendAudioRsp
result (	Rresult"@
NoticeSendAudio
data (Rdata
user_pos (RuserPos">
NoticeYingKou
user_pos (RuserPos
card (Rcard"
	NoticePao*ã
Result
success
paramater_error
server_error
key_exchange_failed
other_player_login

auth_faild
gold_not_enough
current_in_game
not_exist_room	
not_in_room

sit_already_has
round_not_enough
pos_has_player
already_sit
invaild_operator
no_support_command
no_permission_distroy
current_in_room
no_position*5
GangType
AN_GANG
	MING_GANG
	PENG_GANG
ç 
protocol.protomsg/common.protomsg/login.protomsg/user.protomsg/ddz.proto"ë
C2S

session_id (R	sessionId3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginReqRlogin9
create_roomëN (2.msg.user.CreateRoomReqR
createRoom3
	join_roomíN (2.msg.user.JoinRoomReqRjoinRoom6

leave_roomìN (2.msg.user.LeaveRoomReqR	leaveRoom0
sit_downîN (2.msg.user.SitDownReqRsitDown0
game_cmdïN (2.msg.user.GameCmdReqRgameCmd<
distroy_roomñN (2.msg.user.DistroyRoomReqRdistroyRoomR
confirm_distroy_roomóN (2.msg.user.ConfirmDistroyRoomReqRconfirmDistroyRoomD
get_my_room_listòN (2.msg.user.GetMyRoomListReqRgetMyRoomList3

send_audioôN (2.msg.user.SendAudioR	sendAudio=
fast_spake_reqöN (2.msg.user.FastSpakeReqRfastSpakeReq"§
S2C

session_id (R	sessionId
is_push (RisPush3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginRspRlogin9
create_roomëN (2.msg.user.CreateRoomRspR
createRoom3
	join_roomíN (2.msg.user.JoinRoomRspRjoinRoom6

leave_roomìN (2.msg.user.LeaveRoomRspR	leaveRoom0
sit_downîN (2.msg.user.SitDownRspRsitDown0
game_cmdïN (2.msg.user.GameCmdRspRgameCmd<
distroy_roomñN (2.msg.user.DistroyRoomRspRdistroyRoomR
confirm_distroy_roomóN (2.msg.user.ConfirmDistroyRoomRspRconfirmDistroyRoomD
get_my_room_listòN (2.msg.user.GetMyRoomListRspRgetMyRoomList>
push_user_info°ú (2.msg.user.PushUserInfoRpushUserInfoG
refresh_room_info¢ú (2.msg.user.RefreshRoomInfoRrefreshRoomInfo;
push_sit_down£ú (2.msg.user.PushSitDownRpushSitDown1
	deal_card§ú (2.msg.user.DealCardRdealCard>
push_draw_card•ú (2.msg.user.PushDrawCardRpushDrawCard>
push_play_card¶ú (2.msg.user.PushPlayCardRpushPlayCardD
notice_play_cardßú (2.msg.user.NoticePlayCardRnoticePlayCardD
notice_peng_card®ú (2.msg.user.NoticePengCardRnoticePengCardD
notice_gang_card©ú (2.msg.user.NoticeGangCardRnoticeGangCard`
push_player_operator_state™ú (2!.msg.user.PushPlayerOperatorStateRpushPlayerOperatorStateD
notice_game_over´ú (2.msg.user.NoticeGameOverRnoticeGameOverc
notice_player_connect_state¨ú (2".msg.user.NoticePlayerConnectStateRnoticePlayerConnectStateG
push_all_room_info› (2.msg.user.PushAllRoomInfoRpushAllRoomInfoC
update_cost_goldﬁ (2.msg.user.UpdateCostGoldRupdateCostGold\
notice_other_distroy_roomﬂ (2 .msg.user.NoticeOtherDistoryRoomRnoticeOtherDistroyRoomL
notice_other_refuse‡ (2.msg.user.NoticeOtherRefuseRnoticeOtherRefuse_
notice_player_distroy_room· (2!.msg.user.NoticePlayerDistroyRoomRnoticePlayerDistroyRoomY
refresh_player_cur_score‚ (2.msg.user.RefreshPlayerCurScoreRrefreshPlayerCurScoreL
notice_total_sattle„ (2.msg.user.NoticeTotalSattleRnoticeTotalSattleO
notice_special_event‰ (2.msg.user.NoticeSpecailEventRnoticeSpecialEventC
notice_ting_cardÂ (2.msg.user.NoticeTingCardRnoticeTingCard@
notice_ying_kouÊ (2.msg.user.NoticeYingKouRnoticeYingKouF
notice_send_audioÁ (2.msg.user.NoticeSendAudioRnoticeSendAudioF
notice_fast_spakeË (2.msg.user.NoticeFastSpakeRnoticeFastSpake6

send_audioÈ (2.msg.user.SendAudioRspR	sendAudio3

notice_paoÍ (2.msg.user.NoticePaoR	noticePaoC
update_resource±Í (2.msg.user.UpdateResourceRupdateResourceG
update_room_state≤Í (2.msg.user.UpdateRoomStateRupdateRoomState:
handle_errorëø (2.msg.user.HandleErrorRhandleErrorA
ServerSendCard≠ú (2.msg.ddz.ServerSendCardRServerSendCardJ
NoticePointDemandÆú (2.msg.ddz.NoticePointDemandRNoticePointDemandG
NoticeMainPlayerØú (2.msg.ddz.NoticeMainPlayerRNoticeMainPlayerA
NoticeSendCard±ú (2.msg.ddz.NoticeSendCardRNoticeSendCardJ
ServerPointDemand≤ú (2.msg.ddz.ServerPointDemandRServerPointDemandJ
NoticeDDZGameOver≥ú (2.msg.ddz.NoticeDDZGameOverRNoticeDDZGameOver