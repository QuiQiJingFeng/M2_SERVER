
�
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
�
msg/login.proto	msg.login"�
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
�
msg/user.protomsg.user"�
UserInfo
user_id (	RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_ip (	RuserIp
user_pos (RuserPos
is_sit (RisSit"�
CreateRoomReq
	game_type (RgameType
round (Rround
pay_type (RpayType
seat_num (RseatNum$
is_friend_room (RisFriendRoom"
is_open_voice (RisOpenVoice
is_open_gps (R	isOpenGps#
other_setting (RotherSetting"�
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
result (2.msg.user.ResultRresult"�
PushUserInfo
user_id (	RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_ip (	RuserIp
gold_num (RgoldNum
	room_list (RroomList"�
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
sit_list (2.msg.user.SitItemRsitList"O
DealCard
zpos (Rzpos
user_pos (RuserPos
cards (Rcards"V
PushDrawCard
user_id (	RuserId
card (Rcard
user_pos (RuserPos"2
GPItem
value (Rvalue
type (Rtype"�
PushPlayCard
user_id (	RuserId
user_pos (RuserPos
	card_list (RcardList-
	peng_list (2.msg.user.GPItemRpengList-
	gang_list (2.msg.user.GPItemRgangList"X
NoticePlayCard
user_id (	RuserId
card (Rcard
user_pos (RuserPos"X
NoticePengCard
user_id (	RuserId
card (Rcard
user_pos (RuserPos"�
NoticeGangCard
user_id (	RuserId
card (Rcard/
	gang_type (2.msg.user.GangTypeRgangType
user_pos (RuserPos"[
PushPlayerOperatorState%
operator_state (	RoperatorState
user_pos (RuserPos"r
Item
user_id (	RuserId
up_score (RupScore
	card_list (RcardList
user_pos (RuserPos"N
NoticeGameOver
type (Rtype(
players (2.msg.user.ItemRplayers"M
NoticePlayersDisconnect
user_id (	RuserId
user_pos (RuserPos"
HandleError*�
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
sit_already_has
no_bind_room_id
call_center_fail
invalid_paramater
round_not_enough*5
GangType
AN_GANG
	MING_GANG
	PENG_GANG
�
protocol.protomsg/common.protomsg/login.protomsg/user.proto"�
C2S

session_id (R	sessionId3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginReqRlogin,
logout (2.msg.login.LogoutReqRlogout9
create_room�N (2.msg.user.CreateRoomReqR
createRoom3
	join_room�N (2.msg.user.JoinRoomReqRjoinRoom6

leave_room�N (2.msg.user.LeaveRoomReqR	leaveRoom0
sit_down�N (2.msg.user.SitDownReqRsitDown0
game_cmd�N (2.msg.user.GameCmdReqRgameCmd"�
S2C

session_id (R	sessionId
is_push (RisPush3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginRspRlogin,
logout (2.msg.login.LogoutRspRlogout9
create_room�N (2.msg.user.CreateRoomRspR
createRoom3
	join_room�N (2.msg.user.JoinRoomRspRjoinRoom6

leave_room�N (2.msg.user.LeaveRoomRspR	leaveRoom0
sit_down�N (2.msg.user.SitDownRspRsitDown0
game_cmd�N (2.msg.user.GameCmdRspRgameCmd>
push_user_info�� (2.msg.user.PushUserInfoRpushUserInfoG
refresh_room_info�� (2.msg.user.RefreshRoomInfoRrefreshRoomInfo;
push_sit_down�� (2.msg.user.PushSitDownRpushSitDown1
	deal_card�� (2.msg.user.DealCardRdealCard>
push_draw_card�� (2.msg.user.PushDrawCardRpushDrawCard>
push_play_card�� (2.msg.user.PushPlayCardRpushPlayCardD
notice_play_card�� (2.msg.user.NoticePlayCardRnoticePlayCardD
notice_peng_card�� (2.msg.user.NoticePengCardRnoticePengCardD
notice_gang_card�� (2.msg.user.NoticeGangCardRnoticeGangCard`
push_player_operator_state�� (2!.msg.user.PushPlayerOperatorStateRpushPlayerOperatorStateD
notice_game_over�� (2.msg.user.NoticeGameOverRnoticeGameOver_
notice_players_disconnect�� (2!.msg.user.NoticePlayersDisconnectRnoticePlayersDisconnect:
handle_error�� (2.msg.user.HandleErrorRhandleError