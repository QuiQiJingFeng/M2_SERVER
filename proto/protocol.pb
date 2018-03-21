
‚
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
—
msg/ddz.protomsg.ddz"0
ReqPointDemand

userDemand (R
userDemand"_
ReqSendCard
nowType (RnowType
nowValue (RnowValue
cardList (RcardList"W
ServerPointDemand
	userExtra (R	userExtra$
userNowDemand (RuserNowDemand"l
ServerSendCard
	userExtra (R	userExtra
userCard (RuserCard 
userCardNum (RuserCardNum"Q
NoticePointDemand
	userExtra (R	userExtra

userDemand (R
userDemand"M
NoticeMainPaleyer
	userExtra (R	userExtra
baseCard (RbaseCard"€
NoticeSendCard
	userExtra (R	userExtra
nowType (RnowType
nowValue (RnowValue
cardList (RcardList
Ô
msg/login.proto	msg.login"§
LoginReq3

login_type (2.msg.login.LoginTypeR	loginType
account (	Raccount
token (	Rtoken
	user_name (	RuserName
user_pic (	RuserPic"^
LoginRsp)
result (2.msg.login.ResultRresult'
reconnect_token (	RreconnectToken"
	LogoutReq"6
	LogoutRsp)
result (2.msg.login.ResultRresult"=
ReconnectReq
user_id (	RuserId
token (	Rtoken"9
ReconnectRsp)
result (2.msg.login.ResultRresult*&
	LoginType

weixin
	reconnect*E
Result
success
fail
unknow_login_type
	auth_fail
‘
msg/user.protomsg.user"c
GPItem
value (Rvalue
	gang_type (RgangType
from (Rfrom
type (Rtype"×
UserInfo
user_id (	RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_ip (	RuserIp
user_pos (RuserPos
is_sit (RisSit
gold_num (RgoldNum
score (Rscore"…
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
result (2.msg.user.ResultRresult"®

GameCmdReq
command (	Rcommand
card (Rcard 
demandPoint (RdemandPoint
nowType (RnowType
nowValue (RnowValue
cardList (RcardList"6

GameCmdRsp(
result (2.msg.user.ResultRresult"Z
RoomItem
room_id (RroomId
state (Rstate
expire_time (R
expireTime"Ä
PushUserInfo
user_id (	RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_ip (	RuserIp
gold_num (RgoldNum/
	room_list (2.msg.user.RoomItemRroomList"@
UpdateRoomState
room_id (RroomId
state (Rstate"’
RefreshRoomInfo
room_id (RroomId,
players (2.msg.user.UserInfoRplayers8
room_setting (2.msg.user.RoomSettingRroomSetting"=
SitItem
user_id (	RuserId
user_pos (RuserPos"T
PushSitDown
room_id (RroomId,
sit_list (2.msg.user.SitItemRsitList"
DealCard
zpos (Rzpos
user_pos (RuserPos
cards (Rcards
random_nums (R
randomNums
	cur_round (RcurRound"V
PushDrawCard
user_id (	RuserId
card (Rcard
user_pos (RuserPos"¬
PushPlayCard
user_id (	RuserId
user_pos (RuserPos
operator (Roperator
	card_list (RcardList/

card_stack (2.msg.user.GPItemR	cardStack"X
NoticePlayCard
user_id (	RuserId
card (Rcard
user_pos (RuserPos"j
NoticePengCard
user_id (	RuserId
user_pos (RuserPos$
item (2.msg.user.GPItemRitem"j
NoticeGangCard
user_id (	RuserId
user_pos (RuserPos$
item (2.msg.user.GPItemRitem"t
PushPlayerOperatorState%
operator_state (	RoperatorState
user_pos (RuserPos
user_id (	RuserId"Š
Item
user_id (	RuserId
user_pos (RuserPos
	cur_score (RcurScore
score (Rscore
	card_list (RcardList"v
NoticeGameOver
	over_type (RoverType(
players (2.msg.user.ItemRplayers

award_list (R	awardList"M
NoticePlayersDisconnect
user_id (	RuserId
user_pos (RuserPos"Š

PlayerInfo
user_id (	RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_ip (	RuserIp
user_pos (RuserPos
is_sit (RisSit
gold_num (RgoldNum
score (Rscore/

card_stack	 (2.msg.user.GPItemR	cardStack"´
PushAllRoomInfo8
room_setting (2.msg.user.RoomSettingRroomSetting
	card_list (RcardList.
players (2.msg.user.PlayerInfoRplayers
operator (	Roperator"%
HandleError
result (	Rresult"+
UpdateResource
gold_num (RgoldNum*Ê
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
no_support_command*5
GangType
AN_GANG
	MING_GANG
	PENG_GANG
–
protocol.protomsg/common.protomsg/login.protomsg/user.protomsg/ddz.proto"ª
C2S

session_id (R	sessionId3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginReqRlogin,
logout (2.msg.login.LogoutReqRlogout5
	reconnect (2.msg.login.ReconnectReqR	reconnect9
create_room‘N (2.msg.user.CreateRoomReqR
createRoom3
	join_room’N (2.msg.user.JoinRoomReqRjoinRoom6

leave_room“N (2.msg.user.LeaveRoomReqR	leaveRoom0
sit_down”N (2.msg.user.SitDownReqRsitDown0
game_cmd•N (2.msg.user.GameCmdReqRgameCmd"”
S2C

session_id (R	sessionId
is_push (RisPush3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginRspRlogin,
logout (2.msg.login.LogoutRspRlogout5
	reconnect (2.msg.login.ReconnectRspR	reconnect9
create_room‘N (2.msg.user.CreateRoomRspR
createRoom3
	join_room’N (2.msg.user.JoinRoomRspRjoinRoom6

leave_room“N (2.msg.user.LeaveRoomRspR	leaveRoom0
sit_down”N (2.msg.user.SitDownRspRsitDown0
game_cmd•N (2.msg.user.GameCmdRspRgameCmd>
push_user_info¡œ (2.msg.user.PushUserInfoRpushUserInfoG
refresh_room_info¢œ (2.msg.user.RefreshRoomInfoRrefreshRoomInfo;
push_sit_down£œ (2.msg.user.PushSitDownRpushSitDown1
	deal_card¤œ (2.msg.user.DealCardRdealCard>
push_draw_card¥œ (2.msg.user.PushDrawCardRpushDrawCard>
push_play_card¦œ (2.msg.user.PushPlayCardRpushPlayCardD
notice_play_card§œ (2.msg.user.NoticePlayCardRnoticePlayCardD
notice_peng_card¨œ (2.msg.user.NoticePengCardRnoticePengCardD
notice_gang_card©œ (2.msg.user.NoticeGangCardRnoticeGangCard`
push_player_operator_stateªœ (2!.msg.user.PushPlayerOperatorStateRpushPlayerOperatorStateD
notice_game_over«œ (2.msg.user.NoticeGameOverRnoticeGameOver_
notice_players_disconnect¬œ (2!.msg.user.NoticePlayersDisconnectRnoticePlayersDisconnectG
push_all_room_infoÝ (2.msg.user.PushAllRoomInfoRpushAllRoomInfoC
update_resource±ê (2.msg.user.UpdateResourceRupdateResourceG
update_room_state²ê (2.msg.user.UpdateRoomStateRupdateRoomState:
handle_error‘¿ (2.msg.user.HandleErrorRhandleErrorA
ServerSendCard­œ (2.msg.ddz.ServerSendCardRServerSendCardJ
NoticePointDemand®œ (2.msg.ddz.NoticePointDemandRNoticePointDemandJ
NoticeMainPaleyer¯œ (2.msg.ddz.NoticeMainPaleyerRNoticeMainPaleyerA
NoticeSendCard°œ (2.msg.ddz.NoticeSendCardRNoticeSendCardJ
ServerPointDemand±œ (2.msg.ddz.ServerPointDemandRServerPointDemand