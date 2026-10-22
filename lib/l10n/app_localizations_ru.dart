// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'collapse';

  @override
  String get chats => 'Чаты';

  @override
  String get contacts => 'Контакты';

  @override
  String get profile => 'Профиль';

  @override
  String get resizeSidebar => 'Изменить ширину панели';

  @override
  String get collapseSidebar => 'Свернуть панель';

  @override
  String get expandSidebar => 'Развернуть панель';

  @override
  String get routeUnavailable => 'Страница недоступна — к чатам';

  @override
  String get signIn => 'Войти';

  @override
  String get register => 'Создать аккаунт';

  @override
  String get username => 'Логин';

  @override
  String get password => 'Пароль';

  @override
  String get displayName => 'Имя';

  @override
  String get usernameHint => 'От 4 до 32 символов';

  @override
  String get passwordHint => 'Не менее 8 символов';

  @override
  String get authHint => 'Аккаунт хранится на этом сервере Tinode.';

  @override
  String get server => 'Сервер';

  @override
  String get missingConfig =>
      'Не задан ключ приложения Tinode. Запустите приложение с файлом client.json от сервера.';

  @override
  String get signOut => 'Выйти';

  @override
  String get signOutConfirm =>
      'Выйти на этом устройстве? Кеш сообщений останется на устройстве, отдельно от данных других аккаунтов.';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get close => 'Закрыть';

  @override
  String get retry => 'Повторить';

  @override
  String get edit => 'Изменить';

  @override
  String get delete => 'Удалить';

  @override
  String get copy => 'Копировать';

  @override
  String get revealSpoiler => 'Показать спойлер';

  @override
  String get reply => 'Ответить';

  @override
  String get forward => 'Переслать';

  @override
  String get deleteForMe => 'Удалить у меня';

  @override
  String get deleteForEveryone => 'Удалить у всех';

  @override
  String get deleteConfirm => 'Удалить это сообщение?';

  @override
  String get copied => 'Скопировано';

  @override
  String get online => 'В сети';

  @override
  String get offline => 'Нет связи — сообщения отправятся после подключения';

  @override
  String get connecting => 'Подключение…';

  @override
  String get connectionError =>
      'Не удалось подключиться. Проверьте сервер и попробуйте снова.';

  @override
  String get authError => 'Не удалось войти. Проверьте логин и пароль.';

  @override
  String get operationError =>
      'Не удалось выполнить действие. Попробуйте ещё раз.';

  @override
  String get emptyChats => 'Чатов пока нет. Найдите собеседника в контактах.';

  @override
  String get emptyContacts => 'Найдите собеседника на этом сервере по логину.';

  @override
  String get search => 'Поиск по логину';

  @override
  String get noResults => 'Контакты не найдены';

  @override
  String get message => 'Сообщение';

  @override
  String get messageHint => 'Написать сообщение…';

  @override
  String get emptyMessages => 'Поздоровайтесь';

  @override
  String get send => 'Отправить';

  @override
  String get attachment => 'Прикрепить';

  @override
  String get photo => 'Фото';

  @override
  String get camera => 'Камера';

  @override
  String get video => 'Видео';

  @override
  String get file => 'Файл';

  @override
  String get audio => 'Голосовое сообщение';

  @override
  String get play => 'Воспроизвести';

  @override
  String get pause => 'Приостановить';

  @override
  String get sticker => 'Изображение как стикер';

  @override
  String get record => 'Записать голосовое сообщение';

  @override
  String get stopRecording => 'Остановить и отправить';

  @override
  String get recording => 'Идёт запись…';

  @override
  String get permissionDenied =>
      'Доступ не разрешён. Его можно включить в настройках устройства.';

  @override
  String get attachmentTooLarge => 'Размер вложения превышает 10 МБ.';

  @override
  String get unsupportedMessage => 'Неподдерживаемое сообщение';

  @override
  String get deletedMessage => 'Сообщение удалено';

  @override
  String get forwardedMessage => 'Пересланное сообщение';

  @override
  String get replying => 'Ответ на сообщение';

  @override
  String get messageUnavailable => 'Это сообщение недоступно.';

  @override
  String get latestMessages => 'Последние сообщения';

  @override
  String newMessages(int count) {
    return 'Новых сообщений: $count';
  }

  @override
  String get unreadMessages => 'Непрочитанные сообщения';

  @override
  String get queued => 'В очереди';

  @override
  String get sending => 'Отправляется';

  @override
  String get sent => 'Отправлено';

  @override
  String get received => 'Доставлено';

  @override
  String get read => 'Прочитано';

  @override
  String get failed => 'Не отправлено';

  @override
  String get about => 'О себе';

  @override
  String get editProfile => 'Изменить профиль';

  @override
  String get changePhoto => 'Изменить фото';

  @override
  String get startChat => 'Написать';

  @override
  String get language => 'Язык';

  @override
  String get systemLanguage => 'Системный';

  @override
  String get english => 'English';

  @override
  String get russian => 'Русский';

  @override
  String get theme => 'Тема';

  @override
  String get systemTheme => 'Системная';

  @override
  String get lightTheme => 'Светлая';

  @override
  String get darkTheme => 'Тёмная';

  @override
  String get notifications => 'Уведомления';

  @override
  String get enableNotifications => 'Включить уведомления';

  @override
  String get pushNotConfigured =>
      'Для пушей нужны настройки Firebase этого приложения и ключи отправки на сервере.';

  @override
  String get notificationsEnabled => 'Уведомления включены';

  @override
  String get selectChat => 'Выберите чат';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get groupName => 'Название группы';

  @override
  String get create => 'Создать';

  @override
  String get members => 'Участники';

  @override
  String get addMember => 'Добавить участника';

  @override
  String get userId => 'ID пользователя';

  @override
  String get download => 'Открыть вложение';

  @override
  String get loading => 'Загрузка…';

  @override
  String get refresh => 'Обновить';

  @override
  String get searchMessages => 'Поиск сообщений';

  @override
  String get searchWords => 'Слова или начало слова';

  @override
  String get searchScope =>
      'Поиск по тексту этого чата, сохранённому на устройстве. Находит слова и начало слова без учёта регистра.';

  @override
  String get indexingMessages => 'Подготовка сохранённых сообщений…';

  @override
  String get searchComplete => 'Вся история чата доступна для поиска';

  @override
  String get searchPartial =>
      'Поиск по сохранённым сообщениям; часть истории ещё не загружена';

  @override
  String get loadOlderMessages => 'Загрузить ещё историю';

  @override
  String get noMessageMatches => 'Сообщения не найдены';

  @override
  String get newerResults => 'Новее';

  @override
  String get olderResults => 'Старее';

  @override
  String get mediaGallery => 'Общий архив';

  @override
  String get mediaVisual => 'Медиа';

  @override
  String get mediaAudio => 'Аудио';

  @override
  String get mediaFiles => 'Файлы';

  @override
  String get mediaCached => 'Офлайн · сохранено на устройстве';

  @override
  String get mediaEmpty => 'Здесь пока пусто';

  @override
  String get mediaUnavailable => 'Это медиа недоступно';

  @override
  String get zoomIn => 'Приблизить';

  @override
  String get zoomOut => 'Отдалить';

  @override
  String get resetZoom => 'Сбросить масштаб';
}
