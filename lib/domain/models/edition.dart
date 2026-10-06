enum Edition {
  ana,
  open;

  static Edition fromDefine(String value) =>
      value == 'ana' ? Edition.ana : Edition.open;
}
