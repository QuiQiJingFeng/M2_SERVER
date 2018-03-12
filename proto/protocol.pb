
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
‚
msg/login.proto	msg.login"§
LoginReq3

login_type (2.msg.login.LoginTypeR	loginType
account (	Raccount
token (	Rtoken
	user_name (	RuserName
user_pic (	RuserPic"|
LoginRsp.
result (2.msg.login.LoginResultRresult'
reconnect_token (	RreconnectToken
user_id (	RuserId"
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
Ì
msg/user.protomsg.user"v
UserInfo
user_id (	RuserId
	user_name (	RuserName
user_pic (	RuserPic
user_pos (RuserPos"@
CreateRoomReq/
	game_type (2.msg.user.GameTypeRgameType"€
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

PrepareReq"6

PrepareRsp(
result (2.msg.user.ResultRresult"
FinishDealReq"9
FinishDealRsp(
result (2.msg.user.ResultRresult"M

GameCmdReq+
command (2.msg.user.CommandRcommand
card (Rcard"6

GameCmdRsp(
result (2.msg.user.ResultRresult"X
RefreshRoomInfo
room_id (RroomId,
players (2.msg.user.UserInfoRplayers"?
DealCard

zhuang_pos (R	zhuangPos
cards (Rcards"!
DealOneCard
card (Rcard"
ZiMo
zi_mo (RziMo"*
NoticeOtherDeal
user_id (	RuserId";
NoticeChuPai
user_id (	RuserId
card (Rcard"K
NoticePlayerState
hu (Rhu
gang (Rgang
peng (Rpeng"R
Item
user_id (	RuserId
score (Rscore
	card_list (RcardList"S
NoticeGameOver
user_id (	RuserId(
players (2.msg.user.ItemRplayers*Ö
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
not_exist_room*
GameType
HZMJ*?
Command
CHI
PENG
GANG

HU_PAI
CHU_PAI
¾
protocol.protomsg/common.protomsg/login.protomsg/user.proto"¯
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

leave_room“N (2.msg.user.LeaveRoomReqR	leaveRoom/
prepare”N (2.msg.user.PrepareReqRprepare9
finish_deal•N (2.msg.user.FinishDealReqR
finishDeal2
	game_comd–N (2.msg.user.GameCmdReqRgameComd"Æ
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

leave_room“N (2.msg.user.LeaveRoomRspR	leaveRoom/
prepare”N (2.msg.user.PrepareRspRprepare9
finish_deal•N (2.msg.user.FinishDealRspR
finishDeal2
	game_comd–N (2.msg.user.GameCmdRspRgameComdG
refresh_room_info¡œ (2.msg.user.RefreshRoomInfoRrefreshRoomInfo1
	deal_card¢œ (2.msg.user.DealCardRdealCard;
deal_one_card£œ (2.msg.user.DealOneCardRdealOneCard%
zi_mo¤œ (2.msg.user.ZiMoRziMoG
notice_other_deal¥œ (2.msg.user.NoticeOtherDealRnoticeOtherDeal>
notice_chu_pai¦œ (2.msg.user.NoticeChuPaiRnoticeChuPaiM
notice_player_state§œ (2.msg.user.NoticePlayerStateRnoticePlayerStateD
notice_game_over¨œ (2.msg.user.NoticeGameOverRnoticeGameOver