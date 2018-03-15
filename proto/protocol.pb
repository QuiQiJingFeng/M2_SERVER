
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
é
msg/login.proto	msg.login"§
LoginReq3

login_type (2.msg.login.LoginTypeR	loginType
account (	Raccount
token (	Rtoken
	user_name (	RuserName
user_pic (	RuserPic"c
LoginRsp.
result (2.msg.login.LoginResultRresult'
reconnect_token (	RreconnectToken"
	LogoutReq";
	LogoutRsp.
result (2.msg.login.LoginResultRresult*&
	LoginType

weixin
	reconnect*J
LoginResult
success
fail
unknow_login_type
	auth_fail

msg/user.protomsg.user"¦
UserInfo
user_id (	RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_ip (	RuserIp
user_pos (RuserPos
is_sit (RisSit"‡
CreateRoomReq
	game_type (RgameType
round (Rround
pay_type (RpayType
seat_num (RseatNum$
is_friend_room (RisFriendRoom"
is_open_voice (RisOpenVoice
is_open_gps (R	isOpenGps#
other_setting (RotherSetting"€
CreateRoomRsp(
result (2.msg.user.ResultRresult
room_id (RroomId,
players (2.msg.user.UserInfoRplayers"&
JoinRoomReq
room_id (RroomId"~
JoinRoomRsp(
result (2.msg.user.ResultRresult
room_id (RroomId,
players (2.msg.user.UserInfoRplayers"
LeaveRoomReq"8
LeaveRoomRsp(
result (2.msg.user.ResultRresult"

SitDownReq
pos (Rpos"6

SitDownRsp(
result (2.msg.user.ResultRresult":

GameCmdReq
command (	Rcommand
card (Rcard"6

GameCmdRsp(
result (2.msg.user.ResultRresult"“
PushUserInfo
user_id (	RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_ip (	RuserIp
gold_num (RgoldNum"Ð
RefreshRoomInfo
room_id (RroomId,
players (2.msg.user.UserInfoRplayers
	game_type (RgameType
round (Rround
pay_type (RpayType
seat_num (RseatNum$
is_friend_room (RisFriendRoom"
is_open_voice (RisOpenVoice
is_open_gps	 (R	isOpenGps#
other_setting
 (RotherSetting"=
SitItem
user_id (	RuserId
user_pos (RuserPos"T
PushSitDown
room_id (RroomId,
sit_list (2.msg.user.SitItemRsitList"4
DealCard
zpos (Rzpos
cards (Rcards";
PushDrawCard
user_id (	RuserId
card (Rcard"
PushPlayCard"=
NoticePlayCard
user_id (	RuserId
card (Rcard"=
NoticePengCard
user_id (	RuserId
card (Rcard"n
NoticeGangCard
user_id (	RuserId
card (Rcard/
	gang_type (2.msg.user.GangTypeRgangType"@
PushPlayerOperatorState%
operator_state (	RoperatorState"W
Item
user_id (	RuserId
up_score (RupScore
	card_list (RcardList"N
NoticeGameOver
type (Rtype(
players (2.msg.user.ItemRplayers*ë
Result
success
fail
already_in_room
not_in_room
nosupport_command
invailed_user_id
no_card
	cannot_hu
cannot_peng	
cannot_gang

cord_command
not_exist_room
sit_already_has*5
GangType
AN_GANG
	MING_GANG
	PENG_GANG
»
protocol.protomsg/common.protomsg/login.protomsg/user.proto"ó
C2S

session_id (R	sessionId3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginReqRlogin,
logout (2.msg.login.LogoutReqRlogout9
create_room‘N (2.msg.user.CreateRoomReqR
createRoom3
	join_room’N (2.msg.user.JoinRoomReqRjoinRoom6

leave_room“N (2.msg.user.LeaveRoomReqR	leaveRoom0
sit_down”N (2.msg.user.SitDownReqRsitDown0
game_cmd•N (2.msg.user.GameCmdReqRgameCmd"ÿ	
S2C

session_id (R	sessionId
is_push (RisPush3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginRspRlogin,
logout (2.msg.login.LogoutRspRlogout9
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
notice_game_over«œ (2.msg.user.NoticeGameOverRnoticeGameOver