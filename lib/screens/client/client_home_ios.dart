// ignore_for_file: invalid_use_of_protected_member
part of 'client_home.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Méthodes iOS de _ClientHomeState — Yassine
// Ce fichier fait partie de la librairie client_home.dart via `part of`.
// Il accède à tous les membres privés du State sans redéclarer les imports.
// ══════════════════════════════════════════════════════════════════════════════

extension _ClientHomeStateIos on _ClientHomeState {

  /// iOS : après un lien d'invitation, même fenêtre « Carte ajoutée » qu'après un scan.
  void _showJoinedIos(String? cardId) {
    final card = _cards.cast<Map?>().firstWhere((c) => c?['id'] == cardId, orElse: () => null);
    if (card == null) { showIosAlert(context, 'Carte ajoutée', 'Ta nouvelle carte est dans tes cartes.'); return; }
    showCardAddedIos(context,
        merchant: (card['merchants'] as Map?) ?? const {}, design: card['card_design'],
        userName: _userName, alreadyMember: false).then((seeCard) {
      if (seeCard == false && mounted) _setTab(1);
    });
  }

  // ── iOS : accueil style Apple (Cartes / Historique) ──────────────────────
  Widget _buildIosHome() {
    final avatar = _profileImageUrl != null
        ? NetworkImage(_profileImageUrl!) as ImageProvider
        : _profileImagePath != null ? FileImage(File(_profileImagePath!)) : null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.qBg,
        resizeToAvoidBottomInset: false,
        body: Stack(children: [
          const Positioned.fill(child: ClientGlowBackground()),
          Positioned.fill(child: iosReadableWidth(Stack(children: [
          Column(children: [
            if (_searching && _tab == 0) SizedBox(height: MediaQuery.paddingOf(context).top),
            // Pendant la recherche, le titre et le sélecteur se replient (comme sur iPhone).
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _searching && _tab == 0
                  ? const SizedBox(width: double.infinity)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
            SafeArea(
                  bottom: false,
                  child: ClientHeader(
                    caption: ClientHeader.today(),
                    title: _tab == 0 ? 'Bonjour $_firstName' : 'Historique',
                    firstName: _firstName,
                    notifCount: _notifCount,
                    cardCount: _cardCount,
                    rewardCount: _rewardCount,
                    recentNotifs: _notifs.take(10).toList(),
                    onNotifTap: _openNotifs,
                    profileActions: ProfileActions(
                      onPersonalInfo: _showPersonalInfo,
                      onPassword: _showChangePassword,
                      onCards: () => Navigator.push(
                        context,
                        platformRoute(
                          builder: (_) => ManageCardsScreen(
                            token: widget.token,
                            userName: _userName,
                            cards: _cards,
                            rewards: _rewards,
                            onRefresh: _refreshManual,
                          ),
                        ),
                      ),
                      onNotifSettings: _openNotifSettingsIos,
                      onHelp: () => Navigator.push(context, Platform.isIOS
                        ? CupertinoPageRoute(builder: (_) => const HelpPageIos(faqs: HelpSheet.faqs, email: 'qarta.contact@gmail.com'))
                        : MaterialPageRoute(builder: (_) => const HelpPageAndroid(faqs: HelpSheet.faqs, email: 'qarta.contact@gmail.com'))),
                      onLogout: _logout,
                      onDelete: _showDeleteAccount,
                      onClearData: () => setState(() => _previewEmpty = !_previewEmpty),
                      previewEmpty: _previewEmpty,
                      showPassword: !_isOAuth,
                    ),
                    avatarImage: avatar,
                    initials: _initials,
                  ),
                ),
                if (_tab == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _rewardPillActive ? 1 : 0,
                        padding: const EdgeInsets.all(2),
                        children: {
                          0: _segLabel('Cartes', _cardCount),
                          1: _segLabel('Récompenses', _rewardCount),
                        },
                        onValueChanged: (v) => v == 1 ? _goToRewards() : _goToCards(),
                      ),
                    ),
                  ),
                        ]),
            ),
            Expanded(child: _buildTabContent()),
          ]),
          // Comme sur iPhone : la barre se cache pendant qu'on tape (clavier ouvert).
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            ClientBottomNav(
              currentTab: _tab,
              onTabChanged: _setTab,
              onScanTap: () => _setTab(1),
            ),
          ]))),
          if (_stampBadge != null) _buildStampBadge(_stampBadge!),
        ]),
      ),
    );
  }

  Widget _segLabel(String label, int n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.qText)),
          TextSpan(text: '  $n', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.qSub)),
        ])),
      );

  // ── iOS : Profil (tab 3) et Notifications (tab 4), plein écran sans barre ──
  Widget _buildIosPage() {
    final avatar = _profileImageUrl != null
        ? NetworkImage(_profileImageUrl!) as ImageProvider
        : _profileImagePath != null ? FileImage(File(_profileImagePath!)) : null;
    final account = _isOAuth ? (_isGoogle ? 'Compte Google' : 'Compte Apple') : _userEmail;
    final cardsTxt = '$_cardCount carte${_cardCount > 1 ? 's' : ''}';
    final Widget body = _tab == 4
        ? ClientNotificationsIos(
            notifs: _notifs,
            filter: _notifFilter,
            onFilter: (f) => setState(() => _notifFilter = f),
            onBack: _closeNotifs,
            onReadAll: _markAllRead,
            onTap: (n) => setState(() {
              n['read'] = true;
              _notifCount = _notifs.where((x) => !(x['read'] as bool)).length;
            }),
          )
        : ClientProfileIos(
            name: _userName,
            subtitle: account.isEmpty ? cardsTxt : '$account · $cardsTxt',
            initials: _initials,
            avatar: avatar,
            cardCount: _cardCount,
            showPassword: !_isOAuth,
            onBack: () => _setTab(_prevTab),
            onAvatarTap: _showPhotoOptions,
            onPersonalInfo: _showPersonalInfo,
            onPassword: _showChangePassword,
            onCards: () => Navigator.push(
              context,
              platformRoute(
                builder: (_) => kIsIOS
                    ? ManageCardsScreenIos(
                        token: widget.token,
                        userName: _userName,
                        cards: _cards,
                        rewards: _rewards,
                        onRefresh: _refreshManual,
                      )
                    : ManageCardsScreen(
                        token: widget.token,
                        userName: _userName,
                        cards: _cards,
                        rewards: _rewards,
                        onRefresh: _refreshManual,
                      ),
              ),
            ),
            onNotifSettings: _openNotifSettingsIos,
            onHelp: () => Navigator.push(context, Platform.isIOS
              ? CupertinoPageRoute(builder: (_) => const HelpPageIos(faqs: HelpSheet.faqs, email: 'qarta.contact@gmail.com'))
              : MaterialPageRoute(builder: (_) => const HelpPageAndroid(faqs: HelpSheet.faqs, email: 'qarta.contact@gmail.com'))),
            onLogout: _logout,
            onDelete: _showDeleteAccount,
            onClearData: () => setState(() => _previewEmpty = !_previewEmpty),
            previewEmpty: _previewEmpty,
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(backgroundColor: context.cBg, body: iosReadableWidth(body)),
    );
  }

  // ── Réglages des notifications (enregistrés à chaque interrupteur) ──
  Future<void> _openNotifSettingsIos() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;

    Future<bool> save(bool push, bool offres, bool visites) async {
      await p.setBool('notif_push', push);
      await p.setBool('notif_offres', offres);
      await p.setBool('notif_visites', visites);
      if (QartaDemo.enabled) return true;
      try {
        final res = await AuthService.authPut('/notifications/preferences', '', {
          'notif_push': push, 'notif_offres': offres, 'notif_visites': visites,
        });
        return res.statusCode >= 200 && res.statusCode < 300;
      } catch (_) {
        return false;
      }
    }

    if (Platform.isIOS) {
      Navigator.push(context, CupertinoPageRoute(builder: (_) => NotificationSettingsPageIos(
        push: p.getBool('notif_push') ?? true,
        offres: p.getBool('notif_offres') ?? true,
        visites: p.getBool('notif_visites') ?? false,
        onSave: save,
      )));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationSettingsPageAndroid(
        push: p.getBool('notif_push') ?? true,
        offres: p.getBool('notif_offres') ?? true,
        visites: p.getBool('notif_visites') ?? false,
        onSave: save,
      )));
    }
  }

  // ── iOS : ouvrir une carte (depuis « Les plus proches ») ─────────────────
  void _openCardIos(Map card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRModal(
        token: widget.token,
        card: card,
        style: CardStyle.fromDesign(card['card_design'],
            merchantLogoUrl: card['merchants']?['logo_url'] as String?, fallbackColor: kNavyCard),
        userName: _userName,
        onStampAdded: _refreshManual,
        onStampEvent: _onStampEvent,
      ),
    );
  }

  // ── iOS : utiliser une récompense (QR + « Récompense utilisée ») ──────────
  void _useRewardIos(String merchantName, Map reward) {
    showRewardQrIos(
      context,
      reward: reward,
      merchantName: merchantName,
      userName: _userName,
      onRedeemed: () {
        if (QartaDemo.enabled) {
          setState(() {
            _rewards = _rewards.where((r) => r['id'] != reward['id']).toList();
            _rewardCount = _rewards.length;
          });
        } else {
          _refreshManual();
        }
      },
    );
  }

  // ── iOS : la carte vient d'être complétée → « Carte complète ! » ──────────
  Future<void> _onRewardUnlockedIos(StampEvent e) async {
    final idx = _cards.indexWhere((c) => c['id'] == e.cardId);
    if (idx < 0) return;
    final card = _cards[idx] as Map;
    final merchant = (card['merchants'] as Map?) ?? {};
    final useNow = await showRewardUnlockedIos(
      context, merchant: merchant, design: card['card_design'], userName: _userName,
    );
    if (!mounted) return;
    // La carte repart avec le surplus (souvent 0).
    setState(() {
      final i = _cards.indexWhere((c) => c['id'] == e.cardId);
      if (i >= 0) {
        final c = Map<String, dynamic>.from(_cards[i] as Map);
        if (e.isPoints) { c['points_count'] = e.newCount; } else { c['stamps_count'] = e.newCount; }
        _cards[i] = c;
      }
    });
    Map? reward;
    if (QartaDemo.enabled) {
      reward = {
        'id': 'r-demo-${DateTime.now().millisecondsSinceEpoch}',
        'merchant_id': card['merchant_id'],
        'merchant_name': merchant['business_name'],
        'description': merchant['reward_description'],
        'card_design': card['card_design'],
        'merchant': merchant,
      };
      setState(() { _rewards = [..._rewards, reward]; _rewardCount = _rewards.length; });
    } else {
      _refreshCard(e.cardId);
      await _loadRewardsCount();
      reward = _rewards.cast<Map?>().firstWhere((r) => r?['merchant_id'] == card['merchant_id'], orElse: () => null);
    }
    if (!mounted) return;
    _goToRewards();
    if (useNow == true && reward != null) {
      _useRewardIos(merchant['business_name'] as String? ?? '', reward);
    }
  }
}
