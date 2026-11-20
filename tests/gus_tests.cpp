#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "theme.h"
#include "translator.h"

class GusTests : public QObject {
    Q_OBJECT

private slots:
    // A fake qs that remembers its arguments, so tests never touch the real desktop.
    static QString fakeQs(const QTemporaryDir &dir, const QByteArray &listOutput)
    {
        const QString path = dir.filePath("qs");
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly))
            return {};
        f.write("#!/bin/sh\necho \"$@\" >> '" + dir.filePath("calls").toUtf8() + "'\n"
                "[ \"$1\" = list ] && printf '" + listOutput + "'\nexit 0\n");
        f.close();
        QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        return path;
    }

    void settingsRoundTrip()
    {
        QTemporaryDir dir;
        {
            Backend backend(dir.path(), dir.path(), fakeQs(dir, ""));
            backend.setMinWait(10);
            backend.setMaxWait(40);
            backend.setStay(9);
            backend.setSpeed(150);
            backend.setExplodes(false);
            backend.setFuse(12);
            backend.setSound(false);
            backend.setVolume(35);
            backend.setTootEnabled("tuba", false);
            QVERIFY(backend.save());
        }
        Backend again(dir.path(), dir.path(), fakeQs(dir, ""));
        QCOMPARE(again.minWait(), 10);
        QCOMPARE(again.maxWait(), 40);
        QCOMPARE(again.stay(), 9);
        QCOMPARE(again.speed(), 150);
        QCOMPARE(again.explodes(), false);
        QCOMPARE(again.fuse(), 12);
        QCOMPARE(again.sound(), false);
        QCOMPARE(again.volume(), 35);
        QVERIFY(!again.toots().contains("tuba"));
        QCOMPARE(again.toots().size(), 6);
    }

    void waitsStayInOrderAndInRange()
    {
        QTemporaryDir dir;
        Backend backend(dir.path(), dir.path(), fakeQs(dir, ""));
        backend.setMaxWait(15);
        backend.setMinWait(30);
        QCOMPARE(backend.minWait(), 30);
        QCOMPARE(backend.maxWait(), 30);
        backend.setMaxWait(5);
        QCOMPARE(backend.maxWait(), 30);
        backend.setMinWait(0);
        QCOMPARE(backend.minWait(), int(Backend::MinWaitFloor));
        backend.setStay(500);
        QCOMPARE(backend.stay(), int(Backend::StayCeiling));
        backend.setSpeed(1);
        QCOMPARE(backend.speed(), int(Backend::SpeedFloor));
        backend.setSpeed(9999);
        QCOMPARE(backend.speed(), int(Backend::SpeedCeiling));
        backend.setFuse(0);
        QCOMPARE(backend.fuse(), int(Backend::FuseFloor));
        backend.setFuse(600);
        QCOMPARE(backend.fuse(), int(Backend::FuseCeiling));
        backend.setToots({"opera", "nonsense"});
        QCOMPARE(backend.toots(), QStringList{"opera"});
    }

    void followsWhetherGusIsRunning()
    {
        QTemporaryDir dir;
        Backend backend(dir.path(), dir.path(), fakeQs(dir, "Instance x:\\n  Process ID: 42\\n"));
        QTRY_VERIFY(backend.running());
    }

    void startNeedsTheOverlay()
    {
        QTemporaryDir dir;
        Backend backend(dir.path(), dir.path() + "/missing", fakeQs(dir, ""));
        backend.start();
        QVERIFY(backend.error().contains("missing"));
        QVERIFY(!backend.running());
    }

    void startRunsQuickshellAndSavesFirst()
    {
        QTemporaryDir dir;
        QFile shell(dir.filePath("shell.qml"));
        QVERIFY(shell.open(QIODevice::WriteOnly));
        shell.close();
        Backend backend(dir.path(), dir.path(), fakeQs(dir, ""));
        backend.setStay(12);
        backend.start();
        QVERIFY(backend.error().isEmpty());
        QVERIFY(QFile::exists(backend.settingsPath()));
        QTRY_VERIFY(readAll(dir.filePath("calls")).contains("-p " + dir.path().toUtf8() + " -d"));
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QString("black"));
    }

    void themeReadsAccent()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        QFile colors(dir.path() + "/theme/colors.toml");
        QVERIFY(colors.open(QIODevice::WriteOnly));
        colors.write("accent = \"#112233\"\n");
        colors.close();

        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
    }

    void themeFollowsHyprlandRounding()
    {
        QTemporaryDir dir;
        const QString response = dir.filePath("response.json"), command = dir.filePath("hyprctl");
        auto write = [](const QString &path, const QByteArray &data) {
            QFile file(path);
            return file.open(QIODevice::WriteOnly) && file.write(data) == data.size();
        };
        QVERIFY(write(command, "#!/bin/sh\ncat '" + response.toUtf8() + "'\n"));
        QVERIFY(QFile::setPermissions(command, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        QVERIFY(write(response, "{\"int\":0}"));

        Theme theme(dir.path(), nullptr, command);
        QCOMPARE(theme.radius(), 0);
        QVERIFY(write(response, "{\"int\":6}"));
        QTRY_COMPARE(theme.radius(), 6);
    }

    void translatorFallsBackToEnglish()
    {
        QTemporaryDir dir;
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("en"));
        QVERIFY(translator.translate("Main", "Save").isNull());
    }

    void translatorFollowsTheLanguageFile()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "pt-BR\n");
        write(dir.path() + "/pt.json", R"({"Save": "Guardar", "Open": "Abrir"})");
        write(dir.path() + "/pt-BR.json", R"({"Save": "Salvar"})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("pt-BR"));
        QCOMPARE(translator.translate("Main", "Save"), QString("Salvar"));
        QCOMPARE(translator.translate("Main", "Open"), QString("Abrir"));
        QVERIFY(translator.translate("Main", "Quit").isNull());
    }

    void translatorPicksPluralForms()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "ru\n");
        write(dir.path() + "/en.json", R"({"%n clips": {"one": "%n clip", "other": "%n clips"}})");
        write(dir.path() + "/ru.json", R"({"%n clips": {"one": "%n клип", "few": "%n клипа", "many": "%n клипов", "other": "%n клипа"}})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.translate("Main", "%n clips", nullptr, 21), QString("%n клип"));
        QCOMPARE(translator.translate("Main", "%n clips", nullptr, 22), QString("%n клипа"));
        QCOMPARE(translator.translate("Main", "%n clips", nullptr, 25), QString("%n клипов"));
        QCOMPARE(Translator::pluralCategory("ar", 11), QString("many"));
        QCOMPARE(Translator::pluralCategory("ja", 1), QString("other"));
    }

private:
    static QByteArray readAll(const QString &path)
    {
        QFile f(path);
        return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray();
    }

    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }
};

QTEST_MAIN(GusTests)
#include "gus_tests.moc"
