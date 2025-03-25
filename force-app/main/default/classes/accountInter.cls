public interface accountInter {
    Account getById(Id id);
    List<Account> getAll();
    void save(Account entity);
    void updateEntity(Account entity);
    void deleteEntity(Account entity);
}